const { DynamoDBClient, ScanCommand } = require('@aws-sdk/client-dynamodb');
const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const ddb = new DynamoDBClient({});
const DISHES_TABLE = process.env.DISHES_TABLE;
const ORDERS_TABLE = process.env.ORDERS_TABLE || 'orders';
const DISHES_BUCKET = String(process.env.DISHES_BUCKET || '').trim();
const DISHES_PUBLIC_BASE_URL = String(
  process.env.DISHES_PUBLIC_BASE_URL || '',
).trim();
const AWS_REGION =
  process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'eu-north-1';
const SIGNED_IMAGE_TTL_SECONDS = (() => {
  const parsed = Number(process.env.DISH_IMAGE_SIGNED_URL_TTL_SECONDS);
  if (!Number.isFinite(parsed) || parsed <= 0) return 60 * 60;
  return Math.min(Math.trunc(parsed), 12 * 60 * 60);
})();
const SCAN_PAGE_LIMIT = (() => {
  const parsed = Number(process.env.DISHES_SCAN_PAGE_LIMIT);
  if (!Number.isFinite(parsed) || parsed <= 0) return 120;
  return Math.min(Math.trunc(parsed), 1000);
})();
const SCAN_MAX_PAGES = (() => {
  const parsed = Number(process.env.DISHES_SCAN_MAX_PAGES);
  if (!Number.isFinite(parsed) || parsed <= 0) return 40;
  return Math.min(Math.trunc(parsed), 500);
})();

const s3 = new S3Client({ region: AWS_REGION });
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
  'Access-Control-Allow-Methods': 'OPTIONS,GET',
};

function response(statusCode, payload) {
  return {
    statusCode,
    headers: JSON_HEADERS,
    body: JSON.stringify(payload),
  };
}

function pickString(attrValue, fallback = '') {
  return typeof attrValue?.S === 'string' ? attrValue.S : fallback;
}

function pickNumber(attrValue, fallback = 0) {
  if (typeof attrValue?.N !== 'string') {
    return fallback;
  }
  const parsed = Number(attrValue.N);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function pickNumberMap(attrValue) {
  const source = attrValue?.M;
  if (!source || typeof source !== 'object') return {};
  return Object.fromEntries(
    Object.entries(source).map(([key, value]) => [
      key,
      Math.round(pickNumber(value, 0)),
    ]),
  );
}

function pickBoolean(attrValue, fallback = false) {
  if (typeof attrValue?.BOOL === 'boolean') {
    return attrValue.BOOL;
  }
  return fallback;
}

function resolveDishImageUrl(item) {
  const storedUrl = pickString(item.imageUrl);
  return storedUrl;
}

// Extract the S3 bucket name from a stored URL like:
// https://BUCKET.s3.REGION.amazonaws.com/KEY
function extractBucketFromUrl(url) {
  if (!url) return '';
  const match = url.match(/^https?:\/\/(.+?)\.s3[.\-].*\.amazonaws\.com\//);
  return match ? match[1] : '';
}

// Generate a pre-signed S3 URL for reading the dish image.
// This bypasses S3 bucket public-access restrictions.
async function signDishImageUrl(item) {
  const imageKey = pickString(item.imageKey);
  const storedUrl = pickString(item.imageUrl);

  // Determine the bucket: prefer env var, then extract from stored URL.
  const bucket = DISHES_BUCKET || extractBucketFromUrl(storedUrl);

  // If we have a bucket and an image key, create a signed URL.
  if (bucket && imageKey) {
    try {
      const signedUrl = await getSignedUrl(
        s3,
        new GetObjectCommand({
          Bucket: bucket,
          Key: imageKey,
        }),
        { expiresIn: SIGNED_IMAGE_TTL_SECONDS },
      );
      return signedUrl;
    } catch (err) {
      console.warn('Failed to sign image URL for key:', imageKey, 'bucket:', bucket, err.message);
    }
  }

  // Fallback: if stored URL is already a valid http URL, return it.
  if (storedUrl.startsWith('http')) {
    return storedUrl;
  }

  return '';
}

function pickStringList(attrValue) {
  if (Array.isArray(attrValue?.L)) {
    return attrValue.L
      .map((entry) => (typeof entry?.S === 'string' ? entry.S.trim() : ''))
      .filter(Boolean);
  }
  if (typeof attrValue?.S === 'string') {
    const raw = attrValue.S.trim();
    if (!raw) return [];
    try {
      const decoded = JSON.parse(raw);
      if (Array.isArray(decoded)) {
        return decoded
          .map((item) => String(item || '').trim())
          .filter(Boolean);
      }
    } catch (_) {
      // ignore malformed data
    }
  }
  return [];
}

function mapItemToDish(item) {
  return {
    id: pickString(item.id),
    cookId: pickString(item.cookId),
    cookName: pickString(item.cookName, '@cook'),
    name: pickString(item.name),
    description: pickString(item.description),
    price: pickNumber(item.price, 0),
    imageUrl: resolveDishImageUrl(item),
    imageKey: pickString(item.imageKey),
    rating: pickNumber(item.rating, 0),
    reviewsCount: Math.round(pickNumber(item.reviewsCount, 0)),
    categoryId: pickString(item.categoryId),
    ingredients: pickStringList(item.ingredients),
    isAvailable: pickBoolean(item.isAvailable, true),
    preparationTimeMin: Math.round(pickNumber(item.preparationTimeMin, 30)),
    preparationTimeMax: Math.round(pickNumber(item.preparationTimeMax, 45)),
    monthlyOrderCounts: pickNumberMap(item.monthlyOrderCounts),
    currentMonthOrders: Math.round(pickNumber(item.currentMonthOrders, 0)),
    totalOrders: Math.round(pickNumber(item.totalOrders, 0)),
    createdAt: pickString(item.createdAt, new Date().toISOString()),
  };
}

// Sign all dish image URLs in parallel for best performance.

async function scanAllItemsFromTable(tableName) {
  let lastEvaluatedKey;
  const results = [];
  let pageCount = 0;
  do {
    pageCount += 1;
    const scanResult = await ddb.send(
      new ScanCommand({
        TableName: tableName,
        ExclusiveStartKey: lastEvaluatedKey,
        Limit: SCAN_PAGE_LIMIT,
      }),
    );
    results.push(...(scanResult.Items ?? []));
    lastEvaluatedKey = scanResult.LastEvaluatedKey;
    if (pageCount >= SCAN_MAX_PAGES) {
      break;
    }
  } while (lastEvaluatedKey);
  return results;
}

async function loadDishesRaw() {
  const tableNames = Array.from(
    new Set([DISHES_TABLE, ...FALLBACK_TABLES].filter(Boolean)),
  );
  let lastError = null;

  for (const tableName of tableNames) {
    try {
      return await scanAllItemsFromTable(tableName);
    } catch (error) {
      const code = String(error?.name || '').toLowerCase();
      if (code.includes('resourcenotfound')) {
        lastError = error;
        continue;
      }
      throw error;
    }
  }

  if (lastError) {
    throw lastError;
  }
  return [];
}

async function loadOrdersRaw() {
  if (!ORDERS_TABLE) return [];
  try {
    return await scanAllItemsFromTable(ORDERS_TABLE);
  } catch (error) {
    const code = String(error?.name || '').toLowerCase();
    if (code.includes('resourcenotfound') || code.includes('accessdenied')) {
      console.warn('Skipping computed dish order stats:', error.message || error);
      return [];
    }
    throw error;
  }
}

function parseOrderItems(item) {
  const raw = pickString(item.itemsJson);
  if (!raw) {
    const dishId = pickString(item.dishId);
    return dishId ? [{ dishId, quantity: 1 }] : [];
  }
  try {
    const decoded = JSON.parse(raw);
    if (!Array.isArray(decoded)) return [];
    return decoded
      .map((entry) => ({
        dishId: String(entry?.dishId || '').trim(),
        quantity: Math.max(1, Math.round(Number(entry?.quantity || 1))),
      }))
      .filter((entry) => entry.dishId);
  } catch (_) {
    return [];
  }
}

function orderMonth(item) {
  const candidate = pickString(item.deliveredAt) || pickString(item.createdAt);
  return candidate ? candidate.slice(0, 7) : '';
}

function buildDishOrderStats(orders) {
  const currentMonth = new Date().toISOString().slice(0, 7);
  const stats = new Map();
  for (const order of orders) {
    if (pickString(order.status) !== 'delivered') continue;
    const month = orderMonth(order);
    for (const entry of parseOrderItems(order)) {
      const current = stats.get(entry.dishId) || {
        totalOrders: 0,
        monthlyOrderCounts: {},
        currentMonthOrders: 0,
      };
      current.totalOrders += entry.quantity;
      if (month) {
        current.monthlyOrderCounts[month] =
          (current.monthlyOrderCounts[month] || 0) + entry.quantity;
      }
      current.currentMonthOrders = current.monthlyOrderCounts[currentMonth] || 0;
      stats.set(entry.dishId, current);
    }
  }
  return stats;
}

function applyDishOrderStats(dishes, stats) {
  return dishes.map((dish) => {
    const computed = stats.get(dish.id);
    if (!computed) return dish;
    return {
      ...dish,
      totalOrders: computed.totalOrders,
      monthlyOrderCounts: computed.monthlyOrderCounts,
      currentMonthOrders: computed.currentMonthOrders,
    };
  });
}

function parseBool(value, fallback = null) {
  if (value == null || value === '') return fallback;
  if (typeof value === 'boolean') return value;
  const normalized = String(value).trim().toLowerCase();
  if (normalized === 'true' || normalized === '1') return true;
  if (normalized === 'false' || normalized === '0') return false;
  return fallback;
}

function parseLimit(value, fallback = 100, max = 500) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(Math.trunc(parsed), max);
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
    const query = event?.queryStringParameters || {};
    const dishId = (event?.pathParameters?.id || query.id || '').toString().trim();
    const cookId = (query.cookId || '').toString().trim();
    const categoryId = (query.categoryId || '').toString().trim();
    const onlyAvailable = parseBool(query.onlyAvailable, null);
    const sort = (query.sort || 'newest').toString().trim().toLowerCase();
    const newestFirst = sort !== 'oldest';
    const limit = parseLimit(query.limit, 120, 500);

    const [rawItems, orderItems] = await Promise.all([
      loadDishesRaw(),
      loadOrdersRaw(),
    ]);
    let dishes = applyDishOrderStats(
      rawItems.map(mapItemToDish),
      buildDishOrderStats(orderItems),
    );

    if (dishId) {
      const dish = dishes.find((item) => item.id === dishId);
      if (!dish) {
        return response(404, { message: 'Dish not found.', id: dishId });
      }
      // Sign the image URL for the single dish.
      const rawItem = rawItems.find((raw) => pickString(raw.id) === dishId);
      if (rawItem) {
        const signedUrl = await signDishImageUrl(rawItem);
        if (signedUrl) dish.imageUrl = signedUrl;
      }
      return response(200, { dish });
    }

    if (cookId) {
      dishes = dishes.filter((dish) => dish.cookId === cookId);
    }
    if (categoryId) {
      dishes = dishes.filter((dish) => dish.categoryId === categoryId);
    }
    if (onlyAvailable != null) {
      dishes = dishes.filter((dish) => dish.isAvailable === onlyAvailable);
    }

    dishes.sort((a, b) => {
      if (sort === 'orders_current_month') {
        return (
          b.currentMonthOrders - a.currentMonthOrders ||
          b.totalOrders - a.totalOrders ||
          String(b.createdAt || '').localeCompare(String(a.createdAt || ''))
        );
      }
      if (sort === 'orders_total') {
        return (
          b.totalOrders - a.totalOrders ||
          b.currentMonthOrders - a.currentMonthOrders ||
          String(b.createdAt || '').localeCompare(String(a.createdAt || ''))
        );
      }
      if (newestFirst) {
        return String(b.createdAt || '').localeCompare(String(a.createdAt || ''));
      }
      return String(a.createdAt || '').localeCompare(String(b.createdAt || ''));
    });

    const slicedItems = dishes.slice(0, limit);

    // Sign image URLs in parallel for all returned dishes.
    // Build a lookup from raw DynamoDB items (by id) so we can access imageKey.
    const rawItemById = {};
    for (const raw of rawItems) {
      const id = pickString(raw.id);
      if (id) rawItemById[id] = raw;
    }

    await Promise.all(
      slicedItems.map(async (dish) => {
        const rawItem = rawItemById[dish.id];
        if (rawItem) {
          const signedUrl = await signDishImageUrl(rawItem);
          if (signedUrl) {
            dish.imageUrl = signedUrl;
          }
        }
      }),
    );

    return response(200, {
      items: slicedItems,
      count: Math.min(dishes.length, limit),
      total: dishes.length,
    });
  } catch (error) {
    console.error('dishesList error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
