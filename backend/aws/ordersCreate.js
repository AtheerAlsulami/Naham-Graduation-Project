const {
  DynamoDBClient,
  PutItemCommand,
  UpdateItemCommand,
} = require('@aws-sdk/client-dynamodb');
const { randomUUID } = require('node:crypto');

const ddb = new DynamoDBClient({});
const ORDERS_TABLE = process.env.ORDERS_TABLE || 'orders';
const USERS_TABLE = process.env.USERS_TABLE || 'users';
const NOTIFICATIONS_TABLE = process.env.NOTIFICATIONS_TABLE || 'notifications';
const APPROVAL_TIMEOUT_MINUTES = 10;
const DEFAULT_PREP_MINUTES = 45;
const FALLBACK_TABLES = String(process.env.ORDERS_FALLBACK_TABLES || '')
  .split(',')
  .map((table) => table.trim())
  .filter(Boolean);

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
  if (!event || event.body == null) return {};
  if (typeof event.body === 'object') return event.body;
  if (typeof event.body === 'string') {
    try {
      return JSON.parse(event.body || '{}');
    } catch (_) {
      throw new Error('Invalid JSON body.');
    }
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

function addMinutes(iso, minutes) {
  const date = new Date(iso);
  date.setMinutes(date.getMinutes() + minutes);
  return date.toISOString();
}

function normalizeItems(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const quantity = asInt(item.quantity, 1);
      const price = asNumber(item.price, 0);
      return {
        dishId: asString(item.dishId),
        dishName: asString(item.dishName),
        imageUrl: asString(item.imageUrl),
        quantity: quantity <= 0 ? 1 : quantity,
        price: price < 0 ? 0 : price,
        total: (quantity <= 0 ? 1 : quantity) * (price < 0 ? 0 : price),
        preparationTimeMin: asInt(item.preparationTimeMin, 0),
        preparationTimeMax: asInt(item.preparationTimeMax, 0),
        note: asString(item.note),
      };
    })
    .filter((item) => !!item && !!item.dishId && !!item.dishName);
}

function fallbackAddress(incoming) {
  if (typeof incoming === 'string') {
    const region = incoming.trim();
    return {
      country: 'Saudi Arabia',
      city: region,
      address: region,
      postcode: '',
      lat: 24.7136,
      lng: 46.6753,
    };
  }
  const lat = asNumber(incoming?.lat, 24.7136);
  const lng = asNumber(incoming?.lng, 46.6753);
  return {
    country: asString(incoming?.country, 'Saudi Arabia'),
    city: asString(incoming?.city, 'Riyadh'),
    address: asString(incoming?.address, 'King Abdullah Street, Apt 4B'),
    postcode: asString(incoming?.postcode, '11564'),
    lat,
    lng,
  };
}

function fallbackPayment(incoming) {
  return {
    method: asString(incoming?.method, 'credit_card'),
    cardMask: asString(incoming?.cardMask, '**** 4242'),
    status: asString(incoming?.status, 'paid'),
    transactionId: asString(
      incoming?.transactionId,
      `tx_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    ),
  };
}

function buildTracking(address) {
  const pickupLat = 24.7261;
  const pickupLng = 46.6895;
  const customerLat = asNumber(address.lat, 24.7136);
  const customerLng = asNumber(address.lng, 46.6753);
  return {
    pickupLat,
    pickupLng,
    customerLat,
    customerLng,
    driverLat: pickupLat,
    driverLng: pickupLng,
    updatedAt: new Date().toISOString(),
  };
}

function buildOrder(body) {
  const now = new Date().toISOString();
  const items = normalizeItems(body.items);
  const itemPrepMinutes = items
    .map((item) => asInt(item.preparationTimeMax || item.preparationTimeMin, 0))
    .filter((minutes) => minutes > 0);
  const prepEstimateMinutes = itemPrepMinutes.length
    ? Math.max(...itemPrepMinutes)
    : DEFAULT_PREP_MINUTES;
  const subtotalCalculated = items.reduce((sum, item) => sum + item.total, 0);
  const subtotal =
    subtotalCalculated > 0
      ? subtotalCalculated
      : asNumber(body.subtotal, 0);
  const deliveryFee = asNumber(body.deliveryFee, subtotal > 0 ? 15 : 0);
  const totalAmount = asNumber(body.totalAmount, subtotal + deliveryFee);
  const cookEarnings = asNumber(
    body.cookEarnings,
    totalAmount > 0 ? Math.max(totalAmount - 6.5, 0) : 0,
  );

  const primaryItem = items[0] || {};
  const orderId = asString(
    body.id,
    `ord_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
  );

  const address = fallbackAddress(body.deliveryAddress || body.address || {});
  const payment = fallbackPayment(body.payment || {});
  const tracking = buildTracking(address);

  return {
    id: orderId,
    displayId: asString(body.displayId, `#ORD-${Date.now().toString().slice(-6)}`),
    customerId: asString(body.customerId),
    customerName: asString(body.customerName, 'Customer'),
    customerPhone: asString(body.customerPhone, '+966500000000'),
    cookId: asString(body.cookId),
    cookName: asString(body.cookName, '@cook'),
    driverId: asString(body.driverId, 'driver_demo_001'),
    driverName: asString(body.driverName, 'Demo Driver'),
    driverPhone: asString(body.driverPhone, '+966511223344'),
    status: asString(body.status, 'pending_review'),
    dishId: asString(body.dishId || primaryItem.dishId),
    dishName: asString(body.dishName || primaryItem.dishName, 'Dish'),
    imageUrl: asString(body.imageUrl || primaryItem.imageUrl),
    itemCount: asInt(
      body.itemCount,
      items.reduce((sum, item) => sum + asInt(item.quantity, 1), 0),
    ),
    subtotal,
    deliveryFee,
    totalAmount,
    cookEarnings,
    note: asString(body.note),
    items,
    deliveryAddress: address,
    payment,
    tracking,
    rating: asInt(body.rating, 0),
    cookRating: asInt(body.cookRating, 0),
    serviceRating: asInt(body.serviceRating, 0),
    reviewComment: asString(body.reviewComment),
    prepEstimateMinutes,
    approvalExpiresAt: asString(
      body.approvalExpiresAt,
      addMinutes(asString(body.createdAt, now), APPROVAL_TIMEOUT_MINUTES),
    ),
    deliveryDueAt: asString(body.deliveryDueAt),
    arrivedAt: asString(body.arrivedAt),
    confirmedReceivedAt: asString(body.confirmedReceivedAt),
    lastNudgedAt: asString(body.lastNudgedAt),
    nudgeCount: asInt(body.nudgeCount, 0),
    issueReason: asString(body.issueReason),
    replacementHistory: Array.isArray(body.replacementHistory)
      ? body.replacementHistory
      : [],
    statusHistory: Array.isArray(body.statusHistory)
      ? body.statusHistory
      : [{ status: asString(body.status, 'pending_review'), at: now, actor: 'system' }],
    payoutId: asString(body.payoutId),
    ratedAt: asString(body.ratedAt),
    createdAt: asString(body.createdAt, now),
    updatedAt: now,
    acceptedAt: asString(body.acceptedAt),
    outForDeliveryAt: asString(body.outForDeliveryAt),
    deliveredAt: asString(body.deliveredAt),
    cancelledAt: asString(body.cancelledAt),
  };
}

function toDynamoItem(order) {
  return {
    id: { S: order.id },
    displayId: { S: order.displayId },
    customerId: { S: order.customerId },
    customerName: { S: order.customerName },
    customerPhone: { S: order.customerPhone },
    cookId: { S: order.cookId },
    cookName: { S: order.cookName },
    driverId: { S: order.driverId },
    driverName: { S: order.driverName },
    driverPhone: { S: order.driverPhone },
    status: { S: order.status },
    dishId: { S: order.dishId },
    dishName: { S: order.dishName },
    imageUrl: { S: order.imageUrl },
    itemCount: { N: String(order.itemCount) },
    subtotal: { N: String(order.subtotal) },
    deliveryFee: { N: String(order.deliveryFee) },
    totalAmount: { N: String(order.totalAmount) },
    cookEarnings: { N: String(order.cookEarnings) },
    note: { S: order.note },
    itemsJson: { S: JSON.stringify(order.items || []) },
    deliveryAddressJson: { S: JSON.stringify(order.deliveryAddress || {}) },
    paymentJson: { S: JSON.stringify(order.payment || {}) },
    trackingJson: { S: JSON.stringify(order.tracking || {}) },
    rating: { N: String(order.rating || 0) },
    cookRating: { N: String(order.cookRating || 0) },
    serviceRating: { N: String(order.serviceRating || 0) },
    reviewComment: { S: order.reviewComment || '' },
    prepEstimateMinutes: { N: String(order.prepEstimateMinutes || DEFAULT_PREP_MINUTES) },
    approvalExpiresAt: { S: order.approvalExpiresAt || '' },
    deliveryDueAt: { S: order.deliveryDueAt || '' },
    arrivedAt: { S: order.arrivedAt || '' },
    confirmedReceivedAt: { S: order.confirmedReceivedAt || '' },
    lastNudgedAt: { S: order.lastNudgedAt || '' },
    nudgeCount: { N: String(order.nudgeCount || 0) },
    issueReason: { S: order.issueReason || '' },
    replacementHistoryJson: { S: JSON.stringify(order.replacementHistory || []) },
    statusHistoryJson: { S: JSON.stringify(order.statusHistory || []) },
    payoutId: { S: order.payoutId || '' },
    ratedAt: { S: order.ratedAt || '' },
    createdAt: { S: order.createdAt },
    updatedAt: { S: order.updatedAt },
    acceptedAt: { S: order.acceptedAt || '' },
    outForDeliveryAt: { S: order.outForDeliveryAt || '' },
    deliveredAt: { S: order.deliveredAt || '' },
    cancelledAt: { S: order.cancelledAt || '' },
  };
}

async function putOrder(item) {
  const tableNames = Array.from(
    new Set([ORDERS_TABLE, ...FALLBACK_TABLES, 'orders'].filter(Boolean)),
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
  throw new Error('No writable orders table was found.');
}

async function incrementCustomerOrderCount(customerId) {
  const normalizedCustomerId = asString(customerId);
  if (!normalizedCustomerId || !USERS_TABLE) return;

  try {
    await ddb.send(
      new UpdateItemCommand({
        TableName: USERS_TABLE,
        Key: { id: { S: normalizedCustomerId } },
        UpdateExpression:
          'SET #updatedAt = :updatedAt ADD #ordersPlacedCount :one',
        ExpressionAttributeNames: {
          '#updatedAt': 'updatedAt',
          '#ordersPlacedCount': 'ordersPlacedCount',
        },
        ExpressionAttributeValues: {
          ':updatedAt': { S: new Date().toISOString() },
          ':one': { N: '1' },
        },
      }),
    );
  } catch (error) {
    console.warn('Failed to increment customer order stats:', error);
  }
}

function valueToAttr(value) {
  if (value == null) return { NULL: true };
  if (typeof value === 'string') return { S: value };
  if (typeof value === 'boolean') return { BOOL: value };
  if (typeof value === 'number') return { N: String(value) };
  if (Array.isArray(value)) return { L: value.map(valueToAttr) };
  if (typeof value === 'object') {
    return {
      M: Object.fromEntries(
        Object.entries(value).map(([key, item]) => [key, valueToAttr(item)]),
      ),
    };
  }
  return { S: String(value) };
}

async function createNotification({ userId, userType, title, subtitle, type, data }) {
  if (!NOTIFICATIONS_TABLE || !asString(userId)) return;
  try {
    const notification = {
      id: randomUUID(),
      userId: asString(userId),
      userType: asString(userType, 'customer'),
      title: asString(title),
      subtitle: asString(subtitle),
      type: asString(type, 'order'),
      data: data && typeof data === 'object' ? data : {},
      isRead: false,
      createdAt: new Date().toISOString(),
    };
    await ddb.send(
      new PutItemCommand({
        TableName: NOTIFICATIONS_TABLE,
        Item: Object.fromEntries(
          Object.entries(notification).map(([key, value]) => [key, valueToAttr(value)]),
        ),
      }),
    );
  } catch (error) {
    console.warn('Failed to create order notification:', error);
  }
}

exports.handler = async (event) => {
  const method =
    asString(event?.requestContext?.http?.method || event?.httpMethod).toUpperCase();
  if (method === 'OPTIONS') {
    return response(200, { ok: true });
  }
  if (method !== 'POST') {
    return response(405, { message: 'Method not allowed.' });
  }

  try {
    const body = parseBody(event);
    const order = buildOrder(body);

    if (!order.customerId || !order.cookId || !order.dishId) {
      return response(400, {
        message: 'Missing required fields: customerId, cookId, dishId.',
      });
    }
    if (!Array.isArray(order.items) || order.items.length == 0) {
      return response(400, { message: 'Order must contain at least one item.' });
    }

    await putOrder(toDynamoItem(order));
    await incrementCustomerOrderCount(order.customerId);
    await createNotification({
      userId: order.cookId,
      userType: 'cook',
      title: 'New order waiting for approval',
      subtitle: `${order.customerName} ordered ${order.dishName}`,
      type: 'order',
      data: { orderId: order.id, action: 'pending_review' },
    });
    return response(200, { order });
  } catch (error) {
    console.error('ordersCreate error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
