const { DynamoDBClient, GetItemCommand, ScanCommand } = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});
const ORDERS_TABLE = process.env.ORDERS_TABLE || 'orders';
const FALLBACK_TABLES = String(process.env.ORDERS_FALLBACK_TABLES || '')
  .split(',')
  .map((table) => table.trim())
  .filter(Boolean);

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

function asString(value, fallback = '') {
  if (value == null) return fallback;
  return String(value).trim();
}

function asNumber(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseJsonString(value, fallback) {
  const raw = asString(value);
  if (!raw) return fallback;
  try {
    return JSON.parse(raw);
  } catch (_) {
    return fallback;
  }
}

function pickString(attrValue, fallback = '') {
  return typeof attrValue?.S === 'string' ? attrValue.S : fallback;
}

function pickNumber(attrValue, fallback = 0) {
  const raw = attrValue?.N;
  if (typeof raw !== 'string') return fallback;
  return asNumber(raw, fallback);
}

function toOrder(item) {
  const items = parseJsonString(pickString(item.itemsJson), []);
  const deliveryAddress = parseJsonString(pickString(item.deliveryAddressJson), {});
  const payment = parseJsonString(pickString(item.paymentJson), {});
  const tracking = parseJsonString(pickString(item.trackingJson), {});
  const replacementHistory = parseJsonString(
    pickString(item.replacementHistoryJson),
    [],
  );
  const statusHistory = parseJsonString(pickString(item.statusHistoryJson), []);
  return {
    id: pickString(item.id),
    displayId: pickString(item.displayId),
    customerId: pickString(item.customerId),
    customerName: pickString(item.customerName),
    customerPhone: pickString(item.customerPhone),
    cookId: pickString(item.cookId),
    cookName: pickString(item.cookName),
    driverId: pickString(item.driverId),
    driverName: pickString(item.driverName),
    driverPhone: pickString(item.driverPhone),
    status: pickString(item.status, 'pending_review'),
    dishId: pickString(item.dishId),
    dishName: pickString(item.dishName),
    imageUrl: pickString(item.imageUrl),
    itemCount: Math.round(pickNumber(item.itemCount, 0)),
    subtotal: pickNumber(item.subtotal, 0),
    deliveryFee: pickNumber(item.deliveryFee, 0),
    totalAmount: pickNumber(item.totalAmount, 0),
    cookEarnings: pickNumber(item.cookEarnings, 0),
    note: pickString(item.note),
    items: Array.isArray(items) ? items : [],
    deliveryAddress: deliveryAddress && typeof deliveryAddress === 'object'
      ? deliveryAddress
      : {},
    payment: payment && typeof payment === 'object' ? payment : {},
    tracking: tracking && typeof tracking === 'object' ? tracking : {},
    rating: Math.round(pickNumber(item.rating, 0)),
    cookRating: Math.round(pickNumber(item.cookRating, 0)),
    serviceRating: Math.round(pickNumber(item.serviceRating, 0)),
    reviewComment: pickString(item.reviewComment),
    prepEstimateMinutes: Math.round(pickNumber(item.prepEstimateMinutes, 45)),
    approvalExpiresAt: pickString(item.approvalExpiresAt),
    deliveryDueAt: pickString(item.deliveryDueAt),
    arrivedAt: pickString(item.arrivedAt),
    confirmedReceivedAt: pickString(item.confirmedReceivedAt),
    lastNudgedAt: pickString(item.lastNudgedAt),
    nudgeCount: Math.round(pickNumber(item.nudgeCount, 0)),
    issueReason: pickString(item.issueReason),
    replacementHistory: Array.isArray(replacementHistory) ? replacementHistory : [],
    statusHistory: Array.isArray(statusHistory) ? statusHistory : [],
    payoutId: pickString(item.payoutId),
    ratedAt: pickString(item.ratedAt),
    createdAt: pickString(item.createdAt),
    updatedAt: pickString(item.updatedAt),
    acceptedAt: pickString(item.acceptedAt),
    outForDeliveryAt: pickString(item.outForDeliveryAt),
    deliveredAt: pickString(item.deliveredAt),
    cancelledAt: pickString(item.cancelledAt),
  };
}

async function scanAllItems(tableName) {
  let lastEvaluatedKey;
  const items = [];
  do {
    const result = await ddb.send(
      new ScanCommand({
        TableName: tableName,
        ExclusiveStartKey: lastEvaluatedKey,
      }),
    );
    items.push(...(result.Items || []));
    lastEvaluatedKey = result.LastEvaluatedKey;
  } while (lastEvaluatedKey);
  return items;
}

async function readOrderById(orderId) {
  const tableNames = Array.from(
    new Set([ORDERS_TABLE, ...FALLBACK_TABLES, 'orders'].filter(Boolean)),
  );
  let lastError = null;
  for (const tableName of tableNames) {
    try {
      const result = await ddb.send(
        new GetItemCommand({
          TableName: tableName,
          Key: {
            id: { S: orderId },
          },
        }),
      );
      if (result.Item) {
        return toOrder(result.Item);
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
  if (lastError) throw lastError;
  return null;
}

async function readAllOrders() {
  const tableNames = Array.from(
    new Set([ORDERS_TABLE, ...FALLBACK_TABLES, 'orders'].filter(Boolean)),
  );
  let lastError = null;
  for (const tableName of tableNames) {
    try {
      return await scanAllItems(tableName);
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
  return [];
}

function parseLimit(value, fallback = 120, max = 500) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(Math.trunc(parsed), max);
}

exports.handler = async (event) => {
  const method =
    asString(event?.requestContext?.http?.method || event?.httpMethod).toUpperCase();
  if (method === 'OPTIONS') {
    return response(200, { ok: true });
  }
  if (method !== 'GET') {
    return response(405, { message: 'Method not allowed.' });
  }

  try {
    const query = event?.queryStringParameters || {};
    const path = event?.pathParameters || {};
    const orderId = asString(path.id || path.orderId || query.id);
    const customerId = asString(query.customerId);
    const cookId = asString(query.cookId);
    const status = asString(query.status).toLowerCase();
    const limit = parseLimit(query.limit, 150, 1000);

    if (orderId) {
      const order = await readOrderById(orderId);
      if (!order) {
        return response(404, { message: 'Order not found.', id: orderId });
      }
      return response(200, { order });
    }

    const rawItems = await readAllOrders();
    let orders = rawItems.map(toOrder);

    if (customerId) {
      orders = orders.filter((item) => item.customerId === customerId);
    }
    if (cookId) {
      orders = orders.filter((item) => item.cookId === cookId);
    }
    if (status) {
      orders = orders.filter(
        (item) => asString(item.status).toLowerCase() === status,
      );
    }

    orders.sort((a, b) =>
      String(b.createdAt || '').localeCompare(String(a.createdAt || '')),
    );

    return response(200, {
      items: orders.slice(0, limit),
      count: Math.min(orders.length, limit),
      total: orders.length,
    });
  } catch (error) {
    console.error('ordersList error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
