const { DynamoDBClient, PutItemCommand } = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});
const DISHES_TABLE = process.env.DISHES_TABLE;
const ENV_FALLBACK_TABLES = String(process.env.DISHES_FALLBACK_TABLES || '')
  .split(',')
  .map((table) => table.trim())
  .filter(Boolean);
const DEFAULT_FALLBACK_TABLES = ['cook_dishes', 'naham_dishes', 'dishes'];
const FALLBACK_TABLES = Array.from(
  new Set([...ENV_FALLBACK_TABLES, ...DEFAULT_FALLBACK_TABLES]),
);
const JSON_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'OPTIONS,POST,PUT',
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

function asString(value, fallback = '') {
  if (value == null) return fallback;
  return String(value).trim();
}

function asNumber(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function asInt(value, fallback = 0) {
  return Math.round(asNumber(value, fallback));
}

function asBool(value, fallback = false) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true' || normalized === '1') return true;
    if (normalized === 'false' || normalized === '0') return false;
  }
  return fallback;
}

function toIngredientsList(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => asString(item))
    .filter(Boolean)
    .slice(0, 50);
}

function toDish(body) {
  const createdAt = asString(body.createdAt) || new Date().toISOString();
  const prepMin = asInt(body.preparationTimeMin, 30);
  const prepMaxCandidate = asInt(body.preparationTimeMax, prepMin + 15);
  const prepMax = prepMaxCandidate < prepMin ? prepMin : prepMaxCandidate;
  const dish = {
    id: asString(body.id),
    cookId: asString(body.cookId),
    cookName: asString(body.cookName, '@cook'),
    name: asString(body.name),
    description: asString(body.description),
    price: asNumber(body.price, 0),
    imageUrl: asString(body.imageUrl),
    imageKey: asString(body.imageKey),
    rating: asNumber(body.rating, 0),
    reviewsCount: asInt(body.reviewsCount, 0),
    currentMonthOrders: Math.max(0, asInt(body.currentMonthOrders, 0)),
    totalOrders: Math.max(0, asInt(body.totalOrders, 0)),
    categoryId: asString(body.categoryId),
    ingredients: toIngredientsList(body.ingredients),
    isAvailable: asBool(body.isAvailable, true),
    preparationTimeMin: prepMin,
    preparationTimeMax: prepMax,
    createdAt,
  };

  return dish;
}

function toDynamoItem(dish) {
  return {
    id: { S: dish.id },
    cookId: { S: dish.cookId },
    cookName: { S: dish.cookName },
    name: { S: dish.name },
    description: { S: dish.description },
    price: { N: String(dish.price) },
    imageUrl: { S: dish.imageUrl },
    imageKey: { S: dish.imageKey },
    rating: { N: String(dish.rating) },
    reviewsCount: { N: String(dish.reviewsCount) },
    currentMonthOrders: { N: String(dish.currentMonthOrders) },
    totalOrders: { N: String(dish.totalOrders) },
    categoryId: { S: dish.categoryId },
    ingredients: {
      L: dish.ingredients.map((ingredient) => ({ S: ingredient })),
    },
    isAvailable: { BOOL: dish.isAvailable },
    preparationTimeMin: { N: String(dish.preparationTimeMin) },
    preparationTimeMax: { N: String(dish.preparationTimeMax) },
    createdAt: { S: dish.createdAt },
  };
}

async function putDishWithFallbacks(item) {
  const tableNames = Array.from(
    new Set([DISHES_TABLE, ...FALLBACK_TABLES].filter(Boolean)),
  );

  let lastError = null;
  for (const tableName of tableNames) {
    try {
      await ddb.send(
        new PutItemCommand({
          TableName: tableName,
          Item: item,
        }),
      );
      return;
    } catch (error) {
      const code = String(error?.name || '').toLowerCase();
      if (code.includes('resourcenotfound')) {
        lastError = error;
        continue;
      }
      throw error;
    }
  }

  if (lastError) throw lastError;
  throw new Error('No writable dishes table was found.');
}

exports.handler = async (event) => {
  if (event?.requestContext?.http?.method === 'OPTIONS') {
    return response(200, { ok: true });
  }

  if (!DISHES_TABLE) {
    return response(500, {
      message: 'Server misconfiguration: DISHES_TABLE is not set.',
    });
  }

  try {
    const body = parseBody(event);
    const dish = toDish(body);

    if (!dish.id || !dish.cookId || !dish.name || !dish.categoryId) {
      return response(400, {
        message:
          'Missing required fields. id, cookId, name, and categoryId are required.',
      });
    }
    if (dish.price <= 0) {
      return response(400, { message: 'Dish price must be greater than zero.' });
    }
    if (!dish.imageUrl) {
      return response(400, { message: 'Dish imageUrl is required.' });
    }

    await putDishWithFallbacks(toDynamoItem(dish));
    return response(200, { dish });
  } catch (error) {
    console.error('dishesSave error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
