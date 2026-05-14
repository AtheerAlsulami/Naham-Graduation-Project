const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function loadPricingSuggest(env = {}) {
  const source = fs.readFileSync(path.join(__dirname, 'pricingSuggest.js'), 'utf8');
  const module = { exports: {} };
  const sandbox = {
    console,
    exports: module.exports,
    module,
    process: {
      env: {
        AI_PROVIDER: 'local',
        ...env,
      },
    },
    require,
    setTimeout,
    clearTimeout,
  };
  vm.runInNewContext(source, sandbox, { filename: 'pricingSuggest.js' });
  return module.exports;
}

test('pricingSuggest local provider returns deterministic fallback pricing', async () => {
  const lambda = loadPricingSuggest();

  const response = await lambda.handler({
    requestContext: { http: { method: 'POST' } },
    body: JSON.stringify({
      categoryId: 'najdi',
      preparationMinutes: 45,
      ingredients: [
        { weightGram: 300, costPer100Sar: 4 },
        { weightGram: 200, costPer100Sar: 3 },
      ],
      profitMode: 'percentage',
      profitValue: 25,
    }),
  });

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.metadata.aiProvider, 'local');
  assert.equal(payload.metadata.marketSignal, 'high_demand');
  assert.ok(payload.suggestedPrice > payload.breakdown.baseCost);
  assert.ok(Array.isArray(payload.metadata.insights));
});

test('pricingSuggest rejects missing valid ingredients', async () => {
  const lambda = loadPricingSuggest();

  const response = await lambda.handler({
    requestContext: { http: { method: 'POST' } },
    body: JSON.stringify({
      categoryId: 'baked',
      ingredients: [{ weightGram: 0, costPer100Sar: 3 }],
      profitValue: 10,
    }),
  });

  assert.equal(response.statusCode, 400);
  assert.match(JSON.parse(response.body).message, /ingredient/);
});
