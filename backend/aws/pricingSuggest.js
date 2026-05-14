const crypto = require('crypto');
const https = require('https');

const JSON_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'OPTIONS,POST',
};

function response(statusCode, payload) {
  return {
    statusCode,
    headers: JSON_HEADERS,
    body: JSON.stringify(payload),
  };
}

function parseBody(event) {
  if (!event || event.body == null) {
    return {};
  }
  if (typeof event.body === 'string') {
    try {
      return JSON.parse(event.body || '{}');
    } catch (_) {
      throw new Error('Invalid JSON body.');
    }
  }
  if (typeof event.body === 'object') {
    return event.body;
  }
  throw new Error('Unsupported request body type.');
}

function asNumber(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function normalizeIngredients(rawItems) {
  if (!Array.isArray(rawItems)) {
    return [];
  }
  return rawItems
    .map((item) => {
      const weightGram = asNumber(item?.weightGram, 0);
      const costPer100Sar = asNumber(item?.costPer100Sar, 0);
      if (weightGram <= 0 || costPer100Sar < 0) {
        return null;
      }
      return { weightGram, costPer100Sar };
    })
    .filter(Boolean);
}

function envValue(name) {
  return String(process.env[name] || '').trim();
}

function secretFingerprint(value) {
  const secret = String(value || '').trim();
  if (!secret) {
    return {
      configured: false,
      length: 0,
      sha256Prefix: null,
    };
  }

  return {
    configured: true,
    length: secret.length,
    sha256Prefix: crypto
      .createHash('sha256')
      .update(secret)
      .digest('hex')
      .slice(0, 12),
  };
}

function providerDiagnostics(provider, apiKey, extra = {}) {
  const fingerprint = secretFingerprint(apiKey);
  const diagnostics = {
    provider,
    keyConfigured: fingerprint.configured,
    keyLength: fingerprint.length,
    keySha256Prefix: fingerprint.sha256Prefix,
    ...extra,
  };

  if (provider === 'groq') {
    diagnostics.keyStartsWithGsk = String(apiKey || '').trim().startsWith('gsk_');
  }

  return diagnostics;
}

async function callAI(prompt, context) {
  const provider = String(envValue('AI_PROVIDER') || 'auto')
    .trim()
    .toLowerCase();

  if (provider === 'openai') {
    return callOpenAI(prompt);
  }
  if (provider === 'groq') {
    return callGroq(prompt);
  }
  if (provider === 'gemini') {
    return callGemini(prompt);
  }
  if (provider === 'local') {
    return callLocalPricing(context);
  }
  if (provider !== 'auto') {
    throw new Error(
      `Unsupported AI_PROVIDER "${provider}". Expected: auto, openai, groq, gemini, local.`,
    );
  }

  const providers = [];
  if (envValue('OPENAI_API_KEY')) {
    providers.push({ name: 'openai', call: callOpenAI });
  }
  if (envValue('GROQ_API_KEY')) {
    providers.push({ name: 'groq', call: callGroq });
  }
  if (envValue('GEMINI_API_KEY')) {
    providers.push({ name: 'gemini', call: callGemini });
  }

  if (providers.length === 0) {
    const error = new Error(
      'No AI provider key configured. Set OPENAI_API_KEY, GROQ_API_KEY, or GEMINI_API_KEY.',
    );
    error.code = 'AI_PROVIDER_NOT_CONFIGURED';
    error.statusCode = 503;
    throw error;
  }

  const failures = [];
  for (const p of providers) {
    try {
      return await p.call(prompt);
    } catch (error) {
      failures.push(`${p.name}: ${error.message}`);
      console.error(`Auto provider fallback - ${p.name} failed:`, error.message);
    }
  }

  const error = new Error(`All AI providers failed. ${failures.join(' | ')}`);
  error.code = 'AI_PROVIDER_ALL_FAILED';
  error.statusCode = 502;
  throw error;
}

async function callOpenAI(prompt) {
  const apiKey = envValue('OPENAI_API_KEY');
  if (!apiKey) {
    throw new Error('OPENAI_API_KEY environment variable is not set.');
  }

  const MODEL_SELECTION_FAILED = 'MODEL_SELECTION_FAILED';
  const STATIC_PRIORITY_MODELS = [
    'gpt-4o-mini',
    'gpt-4.1-mini',
    'gpt-4.1',
  ];
  const preferredModel = envValue('OPENAI_MODEL');
  const rawCandidates = [];

  if (preferredModel) {
    rawCandidates.push({ model: preferredModel, source: 'env' });
  }
  for (const model of STATIC_PRIORITY_MODELS) {
    rawCandidates.push({ model, source: 'priority' });
  }

  const candidates = uniqueModelCandidates(rawCandidates);
  const attemptErrors = [];

  for (const candidate of candidates) {
    try {
      const text = await _fetchOpenAI(candidate.model, apiKey, prompt);
      return {
        text,
        model: candidate.model,
        apiVersion: 'v1',
        modelSource: candidate.source,
        provider: 'openai',
      };
    } catch (error) {
      if (
        error?.code === 'AI_QUOTA_EXCEEDED' ||
        error?.statusCode === 429 ||
        error?.code === 'AI_AUTH_INVALID' ||
        error?.statusCode === 401 ||
        error?.statusCode === 403
      ) {
        throw error;
      }
      const reason = `${candidate.model}: ${error.message}`;
      attemptErrors.push(reason);
      console.error('OpenAI attempt failed:', reason);
    }
  }

  const details = [
    preferredModel ? `preferredModel=${preferredModel}` : 'preferredModel=none',
    candidates.length > 0
      ? `candidates=${candidates.map((c) => c.model).join(', ')}`
      : 'candidates=none',
    attemptErrors.length > 0
      ? `attemptErrors=${attemptErrors.join(' | ')}`
      : 'attemptErrors=none',
  ]
    .filter(Boolean)
    .join('; ');

  const error = new Error(
    `MODEL_SELECTION_FAILED: Unable to select a working OpenAI model. ${details}`,
  );
  error.code = MODEL_SELECTION_FAILED;
  error.statusCode = 502;
  throw error;
}

async function callGroq(prompt) {
  const apiKey = envValue('GROQ_API_KEY');
  if (!apiKey) {
    throw new Error('GROQ_API_KEY environment variable is not set.');
  }
  if (!apiKey.startsWith('gsk_')) {
    const error = new Error('GROQ_API_KEY has an invalid format. Groq keys should start with gsk_.');
    error.code = 'AI_AUTH_INVALID';
    error.statusCode = 401;
    error.diagnostics = providerDiagnostics('groq', apiKey, {
      model: envValue('GROQ_MODEL') || null,
      reason: 'invalid_key_format',
    });
    throw error;
  }

  const MODEL_SELECTION_FAILED = 'MODEL_SELECTION_FAILED';
  const STATIC_PRIORITY_MODELS = [
    'openai/gpt-oss-20b',
    'llama-3.1-8b-instant',
    'llama-3.3-70b-versatile',
  ];
  const preferredModel = envValue('GROQ_MODEL');
  const rawCandidates = [];

  if (preferredModel) {
    rawCandidates.push({ model: preferredModel, source: 'env' });
  }
  for (const model of STATIC_PRIORITY_MODELS) {
    rawCandidates.push({ model, source: 'priority' });
  }

  const candidates = uniqueModelCandidates(rawCandidates);
  const attemptErrors = [];

  for (const candidate of candidates) {
    try {
      const text = await _fetchGroq(candidate.model, apiKey, prompt);
      return {
        text,
        model: candidate.model,
        apiVersion: 'openai/v1',
        modelSource: candidate.source,
        provider: 'groq',
      };
    } catch (error) {
      if (
        error?.code === 'AI_QUOTA_EXCEEDED' ||
        error?.statusCode === 429 ||
        error?.code === 'AI_AUTH_INVALID' ||
        error?.statusCode === 401 ||
        error?.statusCode === 403
      ) {
        throw error;
      }
      const reason = `${candidate.model}: ${error.message}`;
      attemptErrors.push(reason);
      console.error('Groq attempt failed:', reason);
    }
  }

  const details = [
    preferredModel ? `preferredModel=${preferredModel}` : 'preferredModel=none',
    candidates.length > 0
      ? `candidates=${candidates.map((c) => c.model).join(', ')}`
      : 'candidates=none',
    attemptErrors.length > 0
      ? `attemptErrors=${attemptErrors.join(' | ')}`
      : 'attemptErrors=none',
  ]
    .filter(Boolean)
    .join('; ');

  const error = new Error(
    `MODEL_SELECTION_FAILED: Unable to select a working Groq model. ${details}`,
  );
  error.code = MODEL_SELECTION_FAILED;
  error.statusCode = 502;
  throw error;
}

async function callGemini(prompt) {
  const apiKey = envValue('GEMINI_API_KEY');
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY environment variable is not set.');
  }

  const MODEL_SELECTION_FAILED = 'MODEL_SELECTION_FAILED';
  const STATIC_PRIORITY_MODELS = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash-lite',
    'gemini-1.5-flash',
    'gemini-1.5-flash-8b',
  ];
  const API_VERSIONS = ['v1', 'v1beta'];
  const preferredModel = normalizeModelName(envValue('GEMINI_MODEL'));

  let discoveredModels = [];
  let discoveryError = null;
  try {
    discoveredModels = await _listModels(apiKey);
  } catch (error) {
    discoveryError = error;
    console.error('Gemini model discovery failed:', error.message);
  }

  const discoveredGenerateNames = new Set(
    discoveredModels
      .filter((model) =>
        Array.isArray(model?.supportedGenerationMethods) &&
        model.supportedGenerationMethods.includes('generateContent'),
      )
      .map((model) => normalizeModelName(model.name))
      .filter(Boolean),
  );

  const rawCandidates = [];
  if (preferredModel) {
    rawCandidates.push({ model: preferredModel, source: 'env' });
  }

  if (discoveredGenerateNames.size > 0) {
    for (const model of STATIC_PRIORITY_MODELS) {
      if (discoveredGenerateNames.has(model)) {
        rawCandidates.push({ model, source: 'priority' });
      }
    }
    for (const model of discoveredGenerateNames) {
      rawCandidates.push({ model, source: 'discovered' });
    }
  } else {
    for (const model of STATIC_PRIORITY_MODELS) {
      rawCandidates.push({ model, source: 'priority' });
    }
  }

  const candidates = uniqueModelCandidates(rawCandidates);
  const attemptErrors = [];

  for (const candidate of candidates) {
    for (const version of API_VERSIONS) {
      try {
        console.log(`Attempting Gemini API: ${candidate.model} (${version})`);
        const text = await _fetchGemini(version, candidate.model, apiKey, prompt);
        return {
          text,
          model: candidate.model,
          apiVersion: version,
          modelSource: candidate.source,
          provider: 'gemini',
        };
      } catch (error) {
        if (
          error?.code === 'AI_QUOTA_EXCEEDED' ||
          error?.statusCode === 429 ||
          error?.code === 'AI_AUTH_INVALID' ||
          error?.statusCode === 401 ||
          error?.statusCode === 403
        ) {
          throw error;
        }
        const reason = `${candidate.model} (${version}): ${error.message}`;
        attemptErrors.push(reason);
        console.error('Gemini attempt failed:', reason);
      }
    }
  }

  const discoveredNames = discoveredModels
    .map((model) => normalizeModelName(model.name))
    .filter(Boolean);
  const details = [
    preferredModel ? `preferredModel=${preferredModel}` : 'preferredModel=none',
    candidates.length > 0
      ? `candidates=${candidates.map((c) => c.model).join(', ')}`
      : 'candidates=none',
    discoveredNames.length > 0
      ? `discovered=${discoveredNames.join(', ')}`
      : 'discovered=none',
    discoveryError ? `discoveryError=${discoveryError.message}` : null,
    attemptErrors.length > 0
      ? `attemptErrors=${attemptErrors.join(' | ')}`
      : 'attemptErrors=none',
  ]
    .filter(Boolean)
    .join('; ');

  const error = new Error(
    `MODEL_SELECTION_FAILED: Unable to select a working Gemini model. ${details}`,
  );
  error.code = MODEL_SELECTION_FAILED;
  error.statusCode = 502;
  throw error;
}

function _listModels(apiKey) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'generativelanguage.googleapis.com',
      path: `/v1/models?key=${apiKey}`,
      method: 'GET',
    };
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body || '{}');
          if (res.statusCode < 200 || res.statusCode >= 300) {
            const reason = parsed?.error?.message || body || 'Unknown error';
            reject(new Error(`Model listing failed (${res.statusCode}): ${reason}`));
            return;
          }
          if (parsed?.error?.message) {
            reject(new Error(`Model listing failed: ${parsed.error.message}`));
            return;
          }
          resolve(Array.isArray(parsed.models) ? parsed.models : []);
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', (e) => reject(e));
    req.end();
  });
}

function normalizeModelName(raw) {
  return String(raw || '').trim().replace(/^models\//, '');
}

function uniqueModelCandidates(items) {
  const seen = new Set();
  const unique = [];
  for (const item of items) {
    const model = normalizeModelName(item?.model);
    if (!model || seen.has(model)) {
      continue;
    }
    seen.add(model);
    unique.push({
      model,
      source: item?.source || 'discovered',
    });
  }
  return unique;
}

function normalizeProfitMode(rawMode) {
  const normalized = String(rawMode || '').trim().toLowerCase();
  if (normalized === 'fixedamount') {
    return 'fixed';
  }
  return normalized;
}

function callLocalPricing(context) {
  const categoryId = String(context?.categoryId || '').trim();
  const preparationMinutes = asNumber(context?.preparationMinutes, 30);
  const profitMode = normalizeProfitMode(context?.profitMode || 'percentage');
  const profitValue = asNumber(context?.profitValue, 0);
  const currentPrice = asNumber(context?.currentPrice, 0);
  const ingredients = Array.isArray(context?.ingredients) ? context.ingredients : [];

  const breakdown = calculateBasicBreakdown(
    ingredients,
    categoryId,
    preparationMinutes,
    profitMode,
    profitValue,
  );

  const suggestedPrice = clamp(
    breakdown.baseCost + breakdown.profitAmount + breakdown.demandBoost,
    1,
    5000,
  );

  const reasoning = [
    `تم حساب السعر بناءً على تكلفة المكونات (${breakdown.ingredientsCost.toFixed(2)} SAR) والتكاليف التشغيلية والتغليف.`,
    `نمط الربح: ${profitMode === 'fixed' ? 'مبلغ ثابت' : 'نسبة مئوية'} بقيمة ${profitValue}.`,
    currentPrice > 0
      ? `تمت مقارنة السعر الحالي (${currentPrice.toFixed(2)} SAR) مع التكلفة الفعلية.`
      : 'لا يوجد سعر حالي للمقارنة.',
    `إشارة السوق الحالية: ${marketSignal(categoryId)}.`,
  ].join(' ');

  const text = `Suggested price: ${suggestedPrice.toFixed(2)} SAR\nReasoning: ${reasoning}`;
  return Promise.resolve({
    text,
    model: 'local-heuristic-v1',
    apiVersion: 'none',
    modelSource: 'computed',
    provider: 'local',
    suggestedPrice,
    breakdown,
  });
}

function classifyProviderError(errorMessage, statusCode) {
  const normalized = String(errorMessage || '').toLowerCase();
  const isAuth =
    statusCode === 401 ||
    statusCode === 403 ||
    normalized.includes('invalid api key') ||
    normalized.includes('invalid_api_key') ||
    normalized.includes('unauthorized') ||
    normalized.includes('forbidden');
  const isQuota =
    statusCode === 429 ||
    normalized.includes('quota') ||
    normalized.includes('rate limit') ||
    normalized.includes('exceeded your current quota');

  if (isAuth) {
    const error = new Error(errorMessage || 'AI provider authentication failed.');
    error.code = 'AI_AUTH_INVALID';
    error.statusCode = statusCode === 403 ? 403 : 401;
    return error;
  }

  if (isQuota) {
    const error = new Error(errorMessage || 'AI quota exceeded.');
    error.code = 'AI_QUOTA_EXCEEDED';
    error.statusCode = 429;
    return error;
  }
  return null;
}

function _fetchOpenAI(model, apiKey, prompt) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      model,
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.4,
      max_completion_tokens: 700,
    });

    const options = {
      hostname: 'api.openai.com',
      path: '/v1/chat/completions',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
        'Content-Length': Buffer.byteLength(data),
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body || '{}');
          if (res.statusCode < 200 || res.statusCode >= 300) {
            const reason =
              parsed?.error?.message ||
              parsed?.message ||
              body ||
              'Unknown error';
            const rawMessage = `OpenAI error (${res.statusCode}): ${reason}`;
            const classified = classifyProviderError(rawMessage, res.statusCode);
            reject(classified || new Error(rawMessage));
            return;
          }

          const content = parsed?.choices?.[0]?.message?.content;
          if (typeof content === 'string' && content.trim().length > 0) {
            resolve(content);
            return;
          }
          reject(new Error('No content in OpenAI response.'));
        } catch (error) {
          reject(error);
        }
      });
    });

    req.on('error', (error) => reject(error));
    req.write(data);
    req.end();
  });
}

function _fetchGroq(model, apiKey, prompt) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      model,
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.4,
      max_completion_tokens: 700,
    });

    const options = {
      hostname: 'api.groq.com',
      path: '/openai/v1/chat/completions',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
        'Content-Length': Buffer.byteLength(data),
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body || '{}');
          if (res.statusCode < 200 || res.statusCode >= 300) {
            const reason =
              parsed?.error?.message ||
              parsed?.message ||
              body ||
              'Unknown error';
            const rawMessage = `Groq error (${res.statusCode}): ${reason}`;
            const classified = classifyProviderError(rawMessage, res.statusCode);
            if (classified) {
              classified.diagnostics = providerDiagnostics('groq', apiKey, {
                model,
                reason: classified.code,
                statusCode: res.statusCode,
              });
              reject(classified);
              return;
            }
            reject(classified || new Error(rawMessage));
            return;
          }

          const content = parsed?.choices?.[0]?.message?.content;
          if (typeof content === 'string' && content.trim().length > 0) {
            resolve(content);
            return;
          }
          reject(new Error('No content in Groq response.'));
        } catch (error) {
          reject(error);
        }
      });
    });

    req.on('error', (error) => reject(error));
    req.write(data);
    req.end();
  });
}

function _fetchGemini(version, model, apiKey, prompt) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.4,
        maxOutputTokens: 1024,
      }
    });

    const options = {
      hostname: 'generativelanguage.googleapis.com',
      path: `/${version}/models/${model}:generateContent?key=${apiKey}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body || '{}');
          if (res.statusCode < 200 || res.statusCode >= 300) {
            const reason = parsed?.error?.message || body || 'Unknown error';
            const rawMessage = `Google error (${res.statusCode}): ${reason}`;
            const classified = classifyProviderError(rawMessage, res.statusCode);
            reject(classified || new Error(rawMessage));
            return;
          }
          if (parsed.error) {
            reject(new Error(`Google error: ${parsed.error.message}`));
            return;
          }
          const content = parsed.candidates?.[0]?.content?.parts?.[0]?.text;
          if (!content) {
            reject(new Error('No content in response.'));
          } else {
            resolve(content);
          }
        } catch (error) {
          reject(error);
        }
      });
    });

    req.on('error', (error) => reject(error));
    req.write(data);
    req.end();
  });
}

function parseAISuggestion(aiResponse) {
  const priceMatch = aiResponse.match(/(?:suggested price|السعر المقترح)[:\s]*(\d+(?:\.\d+)?)/i);
  if (priceMatch) {
    return parseFloat(priceMatch[1]);
  }
  const numberMatch = aiResponse.match(/(\d+(?:\.\d+)?)/);
  return numberMatch ? parseFloat(numberMatch[1]) : null;
}

function buildAIPrompt(categoryId, preparationMinutes, profitMode, profitValue, currentPrice, ingredients) {
  const ingredientsText = ingredients.map(item =>
    `- ${item.weightGram}g at ${(item.costPer100Sar / 100 * item.weightGram).toFixed(2)} SAR`
  ).join('\n');

  const totalIngredientsCost = ingredients.reduce(
    (sum, item) => sum + (item.weightGram / 100) * item.costPer100Sar,
    0,
  );

  return `
You are a pricing expert for a food delivery app in Saudi Arabia. Suggest a fair market price for a dish based on the following data:

Category: ${categoryId}
Preparation time: ${preparationMinutes} minutes
Ingredients cost: ${totalIngredientsCost.toFixed(2)} SAR
Ingredients details:
${ingredientsText}

Profit mode: ${profitMode}
Profit value: ${profitValue} ${profitMode === 'percentage' ? '%' : 'SAR'}
Current price (if any): ${currentPrice > 0 ? currentPrice + ' SAR' : 'Not set'}

Consider:
- Market rates in Saudi Arabia
- Operational costs (packaging, delivery, platform fees)
- Competitor pricing
- Customer expectations
- Profit margins

Provide a suggested price in SAR, and explain your reasoning briefly in Arabic.

Format your response as:
Suggested price: [number] SAR

Reasoning: [brief explanation]
  `.trim();
}

function calculateBasicBreakdown(ingredients, categoryId, preparationMinutes, profitMode, profitValue) {
  const ingredientsCost = ingredients.reduce(
    (sum, item) => sum + (item.weightGram / 100) * item.costPer100Sar,
    0,
  );

  const packCost = 1.0; 
  const opsCost = (clamp(preparationMinutes, 5, 240) / 60) * 4.0 + 4.5;
  const baseCost = ingredientsCost + packCost + opsCost;
  const profitAmount = profitMode === 'fixed' ? profitValue : baseCost * (profitValue / 100);
  const boost = 2.0;

  return {
    ingredientsCost,
    packagingCost: packCost,
    operationalCost: opsCost,
    profitAmount,
    demandBoost: boost,
    baseCost,
  };
}

function marketSignal(categoryId) {
  switch (categoryId) {
    case 'sweets':
    case 'najdi':
      return 'high_demand';
    case 'baked':
      return 'stable_demand';
    default:
      return 'standard_demand';
  }
}

function marketInsights(categoryId) {
  const signal = marketSignal(categoryId);
  if (signal === 'high_demand') {
    return [
      'High demand potential in this category.',
      'Slight price premium is supported by market activity.',
    ];
  }
  if (signal === 'stable_demand') {
    return [
      'Demand is stable; balanced pricing is recommended.',
      'Packaging quality can increase perceived value.',
    ];
  }
  return [
    'Demand is moderate; focus on strong photos and description.',
    'Keep pricing competitive to increase conversion.',
  ];
}

exports.handler = async (event) => {
  if (event?.requestContext?.http?.method === 'OPTIONS') {
    return response(200, { ok: true });
  }

  let debugAuth = false;

  try {
    const body = parseBody(event);
    debugAuth = body.debugAuth === true;
    const categoryId = String(body.categoryId || '').trim();
    const preparationMinutes = asNumber(body.preparationMinutes, 30);
    const profitMode = String(body.profitMode || 'percentage')
      .trim()
      .toLowerCase();
    const profitValue = asNumber(body.profitValue, 0);
    const currentPrice = asNumber(body.currentPrice, 0);
    const ingredients = normalizeIngredients(body.ingredients);

    if (!categoryId) {
      return response(400, { message: 'categoryId is required.' });
    }
    if (ingredients.length === 0) {
      return response(400, {
        message: 'At least one valid ingredient row is required.',
      });
    }
    if (profitValue < 0) {
      return response(400, { message: 'profitValue must be zero or positive.' });
    }

    const prompt = buildAIPrompt(categoryId, preparationMinutes, profitMode, profitValue, currentPrice, ingredients);
    const aiResult = await callAI(prompt, {
      categoryId,
      preparationMinutes,
      profitMode,
      profitValue,
      currentPrice,
      ingredients,
    });
    const aiResponse = aiResult.text;
    const suggestedPrice = Number.isFinite(aiResult.suggestedPrice)
      ? aiResult.suggestedPrice
      : parseAISuggestion(aiResponse);

    if (suggestedPrice === null || suggestedPrice <= 0) {
      return response(500, { message: 'Failed to parse AI pricing suggestion.' });
    }

    const breakdown = aiResult.breakdown || calculateBasicBreakdown(
      ingredients,
      categoryId,
      preparationMinutes,
      profitMode,
      profitValue,
    );

    return response(200, {
      suggestedPrice: clamp(suggestedPrice, 1, 5000),
      aiReasoning: aiResponse,
      breakdown,
      metadata: {
        categoryId,
        preparationMinutes: Math.round(preparationMinutes),
        profitMode,
        profitValue,
        currentPrice,
        marketSignal: marketSignal(categoryId),
        confidenceScore: 0.85,
        insights: marketInsights(categoryId),
        aiUsed: true,
        aiModel: aiResult.model,
        aiApiVersion: aiResult.apiVersion,
        aiModelSource: aiResult.modelSource,
        aiProvider: aiResult.provider || 'unknown',
      },
    });
  } catch (error) {
    console.error('pricingSuggest error:', error);
    if (error?.code === 'AI_AUTH_INVALID' || error?.statusCode === 401 || error?.statusCode === 403) {
      return response(error?.statusCode === 403 ? 403 : 401, {
        message: 'AI provider authentication failed. Check API key and project/org permissions.',
        error: error.message || 'Invalid API key',
        code: error.code || 'AI_AUTH_INVALID',
        ...(debugAuth && error.diagnostics
          ? { diagnostics: error.diagnostics }
          : {}),
      });
    }
    if (error?.code === 'AI_QUOTA_EXCEEDED' || error?.statusCode === 429) {
      return response(429, {
        message: 'AI quota exceeded. Check provider billing/limits or switch provider.',
        error: error.message || 'Quota exceeded',
        code: error.code || 'AI_QUOTA_EXCEEDED',
      });
    }
    if (error?.code === 'MODEL_SELECTION_FAILED') {
      return response(502, {
        message: 'AI model selection failed.',
        error: error.message || 'Unknown model selection error',
        code: error.code,
      });
    }
    if (error?.statusCode && Number.isInteger(error.statusCode)) {
      return response(error.statusCode, {
        message: 'AI provider request failed.',
        error: error.message || 'Unknown provider error',
        code: error.code || 'AI_PROVIDER_ERROR',
      });
    }
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
