const { DynamoDBClient, ScanCommand } = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});
const USERS_TABLE = process.env.USERS_TABLE;
const ORDERS_TABLE = process.env.ORDERS_TABLE || 'orders';
const REELS_TABLE = process.env.REELS_TABLE || 'reels';
const ENV_FALLBACK_TABLES = String(process.env.USERS_FALLBACK_TABLES || '')
  .split(',')
  .map((table) => table.trim())
  .filter(Boolean);
const DEFAULT_FALLBACK_TABLES = ['users', 'naham_users'];
const FALLBACK_TABLES = Array.from(
  new Set([USERS_TABLE, ...ENV_FALLBACK_TABLES, ...DEFAULT_FALLBACK_TABLES]),
);
const SCAN_PAGE_LIMIT = (() => {
  const parsed = Number(process.env.USERS_SCAN_PAGE_LIMIT);
  if (!Number.isFinite(parsed) || parsed <= 0) return 120;
  return Math.min(Math.trunc(parsed), 1000);
})();
const SCAN_MAX_PAGES = (() => {
  const parsed = Number(process.env.USERS_SCAN_MAX_PAGES);
  if (!Number.isFinite(parsed) || parsed <= 0) return 50;
  return Math.min(Math.trunc(parsed), 500);
})();
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
  if (typeof attrValue?.N !== 'string') return fallback;
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

function parseLimit(value, fallback = 500, max = 2000) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(Math.trunc(parsed), max);
}

function normalizeRole(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizeStatus(value) {
  return String(value || '').trim().toLowerCase();
}

function buildDocuments(item) {
  const documents = [];
  const idUrl = pickString(item.verificationIdUrl);
  const healthUrl = pickString(item.verificationHealthUrl);

  if (idUrl) {
    documents.push({
      title: 'Identity document',
      type: 'id',
      url: idUrl,
    });
  }
  if (healthUrl) {
    documents.push({
      title: 'Health certificate',
      type: 'health',
      url: healthUrl,
    });
  }

  return documents;
}

function pickBool(attrValue, fallback = null) {
  if (typeof attrValue?.BOOL === 'boolean') return attrValue.BOOL;
  if (typeof attrValue?.N === 'string') {
    if (attrValue.N === '1') return true;
    if (attrValue.N === '0') return false;
  }
  if (typeof attrValue?.S === 'string') {
    const v = attrValue.S.trim().toLowerCase();
    if (v === 'true' || v === '1') return true;
    if (v === 'false' || v === '0') return false;
  }
  return fallback;
}

function pickWorkingHours(attrValue) {
  if (typeof attrValue?.S !== 'string') return null;
  const raw = attrValue.S.trim();
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed;
    }
    return null;
  } catch (_) {
    return null;
  }
}

function mapUser(item) {
  const cookStatus = pickString(item.cookStatus);
  const accountStatus = pickString(item.accountStatus);
  const status = accountStatus || cookStatus || 'active';
  const verificationIdUrl = pickString(item.verificationIdUrl);
  const verificationHealthUrl = pickString(item.verificationHealthUrl);

  return {
    id: pickString(item.id),
    name: pickString(item.name),
    displayName: pickString(item.displayName),
    email: pickString(item.email),
    phone: pickString(item.phone),
    role: normalizeRole(pickString(item.role, 'customer')),
    profileImageUrl: pickString(item.profileImageUrl),
    address: pickString(item.address),
    createdAt: pickString(item.createdAt, new Date().toISOString()),
    cookStatus,
    accountStatus,
    status,
    verificationIdUrl,
    verificationHealthUrl,
    documents: buildDocuments(item),
    rating: pickNumber(item.rating, 0),
    totalOrders: Math.round(pickNumber(item.totalOrders, 0)),
    monthlyOrderCounts: pickNumberMap(item.monthlyOrderCounts),
    currentMonthOrders: Math.round(pickNumber(item.currentMonthOrders, 0)),
    followersCount: Math.max(0, Math.round(pickNumber(item.followersCount, 0))),
    reelLikesCount: Math.max(0, Math.round(pickNumber(item.reelLikesCount, 0))),
    ordersPlacedCount: Math.max(
      0,
      Math.round(pickNumber(item.ordersPlacedCount, 0)),
    ),
    likedReelsCount: Math.max(0, Math.round(pickNumber(item.likedReelsCount, 0))),
    followingCooksCount: Math.max(
      0,
      Math.round(pickNumber(item.followingCooksCount, 0)),
    ),
    complaintsCount: Math.round(pickNumber(item.complaintsCount, 0)),
    isOnline: pickBool(item.isOnline),
    dailyCapacity:
      typeof item.dailyCapacity?.N === 'string'
        ? Math.round(pickNumber(item.dailyCapacity, 0))
        : null,
    workingHours: pickWorkingHours(item.workingHours),
  };
}

function sortNewestFirst(items) {
  return [...items].sort((a, b) =>
    String(b.createdAt || '').localeCompare(String(a.createdAt || '')),
  );
}

async function scanTable(tableName, { limit }) {
  let lastEvaluatedKey;
  const collected = [];
  let pageCount = 0;
  do {
    pageCount += 1;
    const pageLimit = Math.min(
      SCAN_PAGE_LIMIT,
      Math.max(1, limit - collected.length),
    );
    const scanResult = await ddb.send(
      new ScanCommand({
        TableName: tableName,
        ExclusiveStartKey: lastEvaluatedKey,
        Limit: pageLimit,
      }),
    );
    collected.push(...(scanResult.Items ?? []));
    lastEvaluatedKey = scanResult.LastEvaluatedKey;
    if (collected.length >= limit || pageCount >= SCAN_MAX_PAGES) {
      break;
    }
  } while (lastEvaluatedKey);
  return collected;
}

async function loadUsersRaw({ limit }) {
  const mergedById = new Map();
  let reachedAnyTable = false;
  let lastError = null;

  for (const tableName of FALLBACK_TABLES) {
    if (!tableName) continue;
    try {
      reachedAnyTable = true;
      const tableItems = await scanTable(tableName, { limit });
      for (const item of tableItems) {
        const id = pickString(item.id);
        const email = pickString(item.email);
        const dedupeKey = id || email;
        if (!dedupeKey) continue;
        mergedById.set(dedupeKey, item);
      }
    } catch (error) {
      const code = String(error?.name || '').toLowerCase();
      if (code.includes('resourcenotfound')) {
        lastError = error;
        continue;
      }
      throw error;
    }
  }

  if (!reachedAnyTable && lastError) {
    throw lastError;
  }

  return [...mergedById.values()];
}

function pickRawString(item, field, fallback = '') {
  return typeof item?.[field]?.S === 'string' ? item[field].S : fallback;
}

function pickRawNumber(item, field, fallback = 0) {
  return pickNumber(item?.[field], fallback);
}

function monthKeyFromOrder(item) {
  const candidate =
    pickRawString(item, 'deliveredAt') || pickRawString(item, 'createdAt');
  if (!candidate) return '';
  return candidate.slice(0, 7);
}

async function loadTableItems(tableName, { limit = 2000 } = {}) {
  if (!tableName) return [];
  try {
    return await scanTable(tableName, { limit });
  } catch (error) {
    const code = String(error?.name || '').toLowerCase();
    if (code.includes('resourcenotfound')) {
      return [];
    }
    throw error;
  }
}

function buildComputedStats({ orders, reels }) {
  const currentMonth = new Date().toISOString().slice(0, 7);
  const customerOrders = new Map();
  const cookTotals = new Map();
  const cookMonthly = new Map();
  const cookReelLikes = new Map();

  for (const order of orders) {
    const customerId = pickRawString(order, 'customerId');
    const cookId = pickRawString(order, 'cookId');
    if (customerId) {
      customerOrders.set(customerId, (customerOrders.get(customerId) || 0) + 1);
    }
    if (cookId && pickRawString(order, 'status') === 'delivered') {
      cookTotals.set(cookId, (cookTotals.get(cookId) || 0) + 1);
      const month = monthKeyFromOrder(order);
      if (month) {
        const counts = cookMonthly.get(cookId) || {};
        counts[month] = (counts[month] || 0) + 1;
        cookMonthly.set(cookId, counts);
      }
    }
  }

  for (const reel of reels) {
    const creatorId = pickRawString(reel, 'creatorId');
    if (!creatorId) continue;
    cookReelLikes.set(
      creatorId,
      (cookReelLikes.get(creatorId) || 0) + Math.max(0, Math.round(pickRawNumber(reel, 'likes', 0))),
    );
  }

  return { currentMonth, customerOrders, cookTotals, cookMonthly, cookReelLikes };
}

function applyComputedStats(users, stats) {
  return users.map((user) => {
    if (user.role === 'cook') {
      const monthlyOrderCounts = stats.cookMonthly.get(user.id) || user.monthlyOrderCounts || {};
      const currentMonthOrders = monthlyOrderCounts[stats.currentMonth] || 0;
      return {
        ...user,
        totalOrders: stats.cookTotals.get(user.id) ?? user.totalOrders,
        monthlyOrderCounts,
        currentMonthOrders,
        reelLikesCount: stats.cookReelLikes.get(user.id) ?? user.reelLikesCount,
      };
    }
    if (user.role === 'customer') {
      return {
        ...user,
        ordersPlacedCount:
          stats.customerOrders.get(user.id) ?? user.ordersPlacedCount,
      };
    }
    return user;
  });
}

exports.handler = async (event) => {
  if (event?.requestContext?.http?.method === 'OPTIONS') {
    return response(200, { ok: true });
  }

  if (!USERS_TABLE) {
    return response(500, {
      message: 'Server misconfiguration: USERS_TABLE is not set.',
    });
  }

  try {
    const query = event?.queryStringParameters || {};
    const pathId = (event?.pathParameters?.id || query.id || '').toString().trim();
    const role = normalizeRole(query.role);
    const cookStatus = normalizeStatus(query.cookStatus);
    const status = normalizeStatus(query.status || query.accountStatus);
    const limit = parseLimit(query.limit, 500, 2000);

    let users = (await loadUsersRaw({ limit: Math.max(limit, 400) }))
      .map(mapUser)
      .filter((item) => item.id);

    const [orders, reels] = await Promise.all([
      loadTableItems(ORDERS_TABLE, { limit: 2000 }),
      loadTableItems(REELS_TABLE, { limit: 2000 }),
    ]);
    users = applyComputedStats(users, buildComputedStats({ orders, reels }));

    if (pathId) {
      const user = users.find((item) => item.id === pathId);
      if (!user) {
        return response(404, { message: 'User not found.', id: pathId });
      }
      return response(200, { user });
    }

    if (role) {
      users = users.filter((item) => item.role === role);
    }
    if (cookStatus) {
      users = users.filter(
        (item) => normalizeStatus(item.cookStatus) === cookStatus,
      );
    }
    if (status) {
      users = users.filter(
        (item) =>
          normalizeStatus(item.status) === status ||
          normalizeStatus(item.accountStatus) === status,
      );
    }

    const sorted = sortNewestFirst(users);
    const sliced = sorted.slice(0, limit);
    return response(200, {
      items: sliced,
      count: sliced.length,
      total: sorted.length,
    });
  } catch (error) {
    console.error('usersList error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
