const {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
  UpdateItemCommand,
} = require('@aws-sdk/client-dynamodb');
const { randomUUID } = require('node:crypto');

const ddb = new DynamoDBClient({});
const ORDERS_TABLE = process.env.ORDERS_TABLE || 'orders';
const USERS_TABLE = process.env.USERS_TABLE || 'users';
const DISHES_TABLE = process.env.DISHES_TABLE || 'dishes';
const PAYOUTS_TABLE = process.env.PAYOUTS_TABLE || 'payouts';
const NOTIFICATIONS_TABLE = process.env.NOTIFICATIONS_TABLE || 'notifications';
const FALLBACK_TABLES = String(process.env.ORDERS_FALLBACK_TABLES || '')
  .split(',')
  .map((table) => table.trim())
  .filter(Boolean);

const DEFAULT_PREP_MINUTES = 45;
const DELIVERY_BUFFER_MINUTES = 30;
const NUDGE_COOLDOWN_MINUTES = 10;

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

function clampInt(value, min, max) {
  return Math.max(min, Math.min(max, asInt(value, min)));
}

function nowIso() {
  return asString(process.env.NOW_ISO) || new Date().toISOString();
}

function addMinutes(iso, minutes) {
  const date = new Date(iso);
  date.setMinutes(date.getMinutes() + minutes);
  return date.toISOString();
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

function parseJsonString(value, fallback) {
  const raw = asString(value);
  if (!raw) return fallback;
  try {
    const decoded = JSON.parse(raw);
    return decoded == null ? fallback : decoded;
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

function toOrder(item) {
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
    items: parseJsonString(pickString(item.itemsJson), []),
    deliveryAddress: parseJsonString(pickString(item.deliveryAddressJson), {}),
    payment: parseJsonString(pickString(item.paymentJson), {}),
    tracking: parseJsonString(pickString(item.trackingJson), {}),
    rating: Math.round(pickNumber(item.rating, 0)),
    cookRating: Math.round(pickNumber(item.cookRating, 0)),
    serviceRating: Math.round(pickNumber(item.serviceRating, 0)),
    reviewComment: pickString(item.reviewComment),
    prepEstimateMinutes: Math.round(
      pickNumber(item.prepEstimateMinutes, DEFAULT_PREP_MINUTES),
    ),
    approvalExpiresAt: pickString(item.approvalExpiresAt),
    deliveryDueAt: pickString(item.deliveryDueAt),
    arrivedAt: pickString(item.arrivedAt),
    confirmedReceivedAt: pickString(item.confirmedReceivedAt),
    lastNudgedAt: pickString(item.lastNudgedAt),
    nudgeCount: Math.round(pickNumber(item.nudgeCount, 0)),
    issueReason: pickString(item.issueReason),
    replacementHistory: parseJsonString(pickString(item.replacementHistoryJson), []),
    statusHistory: parseJsonString(pickString(item.statusHistoryJson), []),
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

function toDynamoItem(order) {
  return {
    id: { S: order.id },
    displayId: { S: asString(order.displayId) },
    customerId: { S: asString(order.customerId) },
    customerName: { S: asString(order.customerName) },
    customerPhone: { S: asString(order.customerPhone) },
    cookId: { S: asString(order.cookId) },
    cookName: { S: asString(order.cookName) },
    driverId: { S: asString(order.driverId) },
    driverName: { S: asString(order.driverName) },
    driverPhone: { S: asString(order.driverPhone) },
    status: { S: asString(order.status, 'pending_review') },
    dishId: { S: asString(order.dishId) },
    dishName: { S: asString(order.dishName) },
    imageUrl: { S: asString(order.imageUrl) },
    itemCount: { N: String(asInt(order.itemCount, 0)) },
    subtotal: { N: String(asNumber(order.subtotal, 0)) },
    deliveryFee: { N: String(asNumber(order.deliveryFee, 0)) },
    totalAmount: { N: String(asNumber(order.totalAmount, 0)) },
    cookEarnings: { N: String(asNumber(order.cookEarnings, 0)) },
    note: { S: asString(order.note) },
    itemsJson: { S: JSON.stringify(order.items || []) },
    deliveryAddressJson: { S: JSON.stringify(order.deliveryAddress || {}) },
    paymentJson: { S: JSON.stringify(order.payment || {}) },
    trackingJson: { S: JSON.stringify(order.tracking || {}) },
    rating: { N: String(asInt(order.rating, 0)) },
    cookRating: { N: String(asInt(order.cookRating, 0)) },
    serviceRating: { N: String(asInt(order.serviceRating, 0)) },
    reviewComment: { S: asString(order.reviewComment) },
    prepEstimateMinutes: {
      N: String(asInt(order.prepEstimateMinutes, DEFAULT_PREP_MINUTES)),
    },
    approvalExpiresAt: { S: asString(order.approvalExpiresAt) },
    deliveryDueAt: { S: asString(order.deliveryDueAt) },
    arrivedAt: { S: asString(order.arrivedAt) },
    confirmedReceivedAt: { S: asString(order.confirmedReceivedAt) },
    lastNudgedAt: { S: asString(order.lastNudgedAt) },
    nudgeCount: { N: String(asInt(order.nudgeCount, 0)) },
    issueReason: { S: asString(order.issueReason) },
    replacementHistoryJson: { S: JSON.stringify(order.replacementHistory || []) },
    statusHistoryJson: { S: JSON.stringify(order.statusHistory || []) },
    payoutId: { S: asString(order.payoutId) },
    ratedAt: { S: asString(order.ratedAt) },
    createdAt: { S: asString(order.createdAt) },
    updatedAt: { S: asString(order.updatedAt) },
    acceptedAt: { S: asString(order.acceptedAt) },
    outForDeliveryAt: { S: asString(order.outForDeliveryAt) },
    deliveredAt: { S: asString(order.deliveredAt) },
    cancelledAt: { S: asString(order.cancelledAt) },
  };
}

function allTableNames() {
  return Array.from(
    new Set([ORDERS_TABLE, ...FALLBACK_TABLES, 'orders'].filter(Boolean)),
  );
}

async function getOrder(orderId) {
  const tableNames = allTableNames();
  let lastError = null;
  for (const tableName of tableNames) {
    try {
      const result = await ddb.send(
        new GetItemCommand({
          TableName: tableName,
          Key: { id: { S: orderId } },
        }),
      );
      if (result.Item) {
        return { order: toOrder(result.Item), tableName };
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
  return { order: null, tableName: tableNames[0] || ORDERS_TABLE };
}

async function putOrder(order) {
  const item = toDynamoItem(order);
  let lastError = null;
  for (const tableName of allTableNames()) {
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

function currentMonthKey(iso) {
  return String(iso || new Date().toISOString()).slice(0, 7);
}

async function incrementCookDeliveredStats(cookId, iso) {
  const normalizedCookId = asString(cookId);
  if (!normalizedCookId || !USERS_TABLE) return;
  const monthKey = currentMonthKey(iso);
  try {
    await ddb.send(
      new UpdateItemCommand({
        TableName: USERS_TABLE,
        Key: { id: { S: normalizedCookId } },
        UpdateExpression:
          'SET #updatedAt = :updatedAt, #lastOrdersMonth = :monthKey ADD #totalOrders :one, #currentMonthOrders :one',
        ExpressionAttributeNames: {
          '#updatedAt': 'updatedAt',
          '#lastOrdersMonth': 'lastOrdersMonth',
          '#totalOrders': 'totalOrders',
          '#currentMonthOrders': 'currentMonthOrders',
        },
        ExpressionAttributeValues: {
          ':updatedAt': { S: iso },
          ':monthKey': { S: monthKey },
          ':one': { N: '1' },
        },
      }),
    );
  } catch (error) {
    console.warn('Failed to increment cook delivered stats:', error);
  }
}

function deliveredDishQuantities(order) {
  const quantities = new Map();
  if (Array.isArray(order.items)) {
    for (const item of order.items) {
      const dishId = asString(item?.dishId);
      if (!dishId) continue;
      const quantity = Math.max(1, asInt(item?.quantity, 1));
      quantities.set(dishId, (quantities.get(dishId) || 0) + quantity);
    }
  }
  if (quantities.size === 0) {
    const dishId = asString(order.dishId);
    if (dishId) {
      quantities.set(dishId, Math.max(1, asInt(order.itemCount, 1)));
    }
  }
  return quantities;
}

async function incrementDishDeliveredStats(order, iso) {
  if (!DISHES_TABLE) return;
  const monthKey = currentMonthKey(iso);
  for (const [dishId, quantity] of deliveredDishQuantities(order).entries()) {
    try {
      await ddb.send(
        new UpdateItemCommand({
          TableName: DISHES_TABLE,
          Key: { id: { S: dishId } },
          UpdateExpression:
            'SET #updatedAt = :updatedAt, #lastOrdersMonth = :monthKey ADD #totalOrders :quantity, #currentMonthOrders :quantity',
          ExpressionAttributeNames: {
            '#updatedAt': 'updatedAt',
            '#lastOrdersMonth': 'lastOrdersMonth',
            '#totalOrders': 'totalOrders',
            '#currentMonthOrders': 'currentMonthOrders',
          },
          ExpressionAttributeValues: {
            ':updatedAt': { S: iso },
            ':monthKey': { S: monthKey },
            ':quantity': { N: String(quantity) },
          },
        }),
      );
    } catch (error) {
      console.warn('Failed to increment dish delivered stats:', error);
    }
  }
}

async function createNotification({ userId, userType, title, subtitle, type, data }) {
  if (!NOTIFICATIONS_TABLE || !asString(userId) || !asString(title)) return;
  try {
    const notification = {
      id: randomUUID(),
      userId: asString(userId),
      userType: asString(userType),
      title: asString(title),
      subtitle: asString(subtitle),
      type: asString(type, 'order'),
      data: data && typeof data === 'object' ? data : {},
      isRead: false,
      createdAt: nowIso(),
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
    console.warn('Failed to create notification:', error);
  }
}

async function createPayout(order, iso) {
  if (!PAYOUTS_TABLE || asString(order.payoutId)) return order.payoutId;
  const payoutId = `payout_${order.id}_${iso.replace(/[-:.TZ]/g, '').slice(0, 14)}`;
  const payout = {
    id: payoutId,
    orderId: order.id,
    cookId: order.cookId,
    cookName: order.cookName,
    customerId: order.customerId,
    amount: asNumber(order.cookEarnings, 0),
    currency: 'SAR',
    status: 'pending_transfer',
    createdAt: iso,
    updatedAt: iso,
  };
  try {
    await ddb.send(
      new PutItemCommand({
        TableName: PAYOUTS_TABLE,
        Item: Object.fromEntries(
          Object.entries(payout).map(([key, value]) => [key, valueToAttr(value)]),
        ),
      }),
    );
  } catch (error) {
    console.warn('Failed to create payout record:', error);
  }
  return payoutId;
}

async function updateCookRatingStats(cookId, rating, iso) {
  const normalizedCookId = asString(cookId);
  if (!normalizedCookId || !USERS_TABLE || rating <= 0) return;
  try {
    await ddb.send(
      new UpdateItemCommand({
        TableName: USERS_TABLE,
        Key: { id: { S: normalizedCookId } },
        UpdateExpression:
          'SET #updatedAt = :updatedAt, #rating = :rating ADD #ratingSum :rating, #ratingCount :one',
        ExpressionAttributeNames: {
          '#updatedAt': 'updatedAt',
          '#rating': 'rating',
          '#ratingSum': 'ratingSum',
          '#ratingCount': 'ratingCount',
        },
        ExpressionAttributeValues: {
          ':updatedAt': { S: iso },
          ':rating': { N: String(rating) },
          ':one': { N: '1' },
        },
      }),
    );
  } catch (error) {
    console.warn('Failed to update cook rating stats:', error);
  }
}

function appendStatusHistory(order, status, iso, actor = 'system', note = '') {
  const history = Array.isArray(order.statusHistory)
    ? [...order.statusHistory]
    : [];
  const last = history[history.length - 1];
  if (last && last.status === status && last.at === iso) return history;
  history.push({ status, at: iso, actor, note });
  return history;
}

function normalizeReplacementItems(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const quantity = Math.max(1, asInt(item.quantity, 1));
      const price = Math.max(0, asNumber(item.price, 0));
      return {
        dishId: asString(item.dishId),
        dishName: asString(item.dishName),
        imageUrl: asString(item.imageUrl),
        quantity,
        price,
        note: asString(item.note),
      };
    })
    .filter((item) => item && item.dishId && item.dishName);
}

function applyReplacementItems(order, items) {
  if (!items.length) return order;
  const subtotal = items.reduce(
    (sum, item) => sum + Math.max(1, asInt(item.quantity, 1)) * asNumber(item.price, 0),
    0,
  );
  const totalAmount = subtotal + asNumber(order.deliveryFee, 0);
  return {
    ...order,
    items,
    itemCount: items.reduce((sum, item) => sum + Math.max(1, asInt(item.quantity, 1)), 0),
    dishId: asString(items[0].dishId, order.dishId),
    dishName: asString(items[0].dishName, order.dishName),
    imageUrl: asString(items[0].imageUrl, order.imageUrl),
    subtotal,
    totalAmount,
    cookEarnings: totalAmount > 0 ? Math.max(totalAmount - 6.5, 0) : 0,
  };
}

function deriveAction(body, currentStatus) {
  const explicit = asString(body.action).toLowerCase();
  if (explicit) return explicit;
  const status = asString(body.status).toLowerCase();
  if (status === 'in_progress') return 'accept';
  if (status === 'ready_for_pickup') return 'mark_ready_for_pickup';
  if (status === 'out_for_delivery') return 'mark_ready_for_pickup';
  if (status === 'cancelled') {
    return currentStatus === 'pending_review' ? 'reject' : 'cancel';
  }
  if (status === 'delivered') return 'direct_delivered';
  if (body.rating != null || body.cookRating != null || body.serviceRating != null) {
    return 'rate';
  }
  return '';
}

function ensureStatus(order, allowed, action) {
  if (allowed.includes(order.status)) return null;
  return response(409, {
    message: `${action} is not allowed while order is ${order.status}.`,
    status: order.status,
  });
}

async function handleAction(order, action, body, iso) {
  let updated = { ...order, updatedAt: iso };
  const actor = asString(body.actor, 'system');

  switch (action) {
    case 'accept': {
      const error = ensureStatus(order, ['pending_review'], action);
      if (error) return { error };
      updated.status = 'in_progress';
      updated.acceptedAt = asString(updated.acceptedAt) || iso;
      updated.prepEstimateMinutes = Math.max(
        DEFAULT_PREP_MINUTES,
        asInt(body.prepEstimateMinutes, updated.prepEstimateMinutes || DEFAULT_PREP_MINUTES),
      );
      updated.deliveryDueAt = addMinutes(
        updated.acceptedAt,
        updated.prepEstimateMinutes + DELIVERY_BUFFER_MINUTES,
      );
      updated.statusHistory = appendStatusHistory(updated, updated.status, iso, actor);
      await createNotification({
        userId: updated.customerId,
        userType: 'customer',
        title: 'Your order was accepted',
        subtitle: `${updated.cookName || 'Cook'} started preparing ${updated.dishName}`,
        type: 'order',
        data: { orderId: updated.id, status: updated.status },
      });
      return { order: updated };
    }

    case 'reject':
    case 'cancel': {
      const error = ensureStatus(
        order,
        ['pending_review', 'in_progress', 'issue_reported', 'replacement_pending_cook'],
        action,
      );
      if (error) return { error };
      updated.status = 'cancelled';
      updated.cancelledAt = asString(updated.cancelledAt) || iso;
      updated.issueReason = asString(body.reason, updated.issueReason);
      updated.statusHistory = appendStatusHistory(updated, updated.status, iso, actor);
      await createNotification({
        userId: updated.customerId,
        userType: 'customer',
        title: action === 'reject' ? 'Order declined' : 'Order cancelled',
        subtitle: updated.issueReason || `${updated.dishName} was cancelled.`,
        type: 'order',
        data: { orderId: updated.id, status: updated.status },
      });
      return { order: updated };
    }

    case 'mark_ready_for_pickup':
    case 'mark_out_for_delivery': {
      const error = ensureStatus(order, ['in_progress'], action);
      if (error) return { error };
      updated.status = 'ready_for_pickup';
      updated.outForDeliveryAt = asString(updated.outForDeliveryAt) || iso;
      updated.deliveryDueAt =
        asString(updated.deliveryDueAt) || addMinutes(iso, DELIVERY_BUFFER_MINUTES);
      updated.statusHistory = appendStatusHistory(updated, updated.status, iso, actor);
      await createNotification({
        userId: updated.customerId,
        userType: 'customer',
        title: 'Your order is ready for pickup',
        subtitle: `${updated.cookName || 'Cook'} finished preparing ${updated.dishName}. Please pick up your order.`,
        type: 'order',
        data: { orderId: updated.id, status: updated.status },
      });
      return { order: updated };
    }

    case 'mark_arrived': {
      const error = ensureStatus(order, ['ready_for_pickup', 'out_for_delivery', 'in_progress'], action);
      if (error) return { error };
      updated.status = 'awaiting_customer_confirmation';
      updated.arrivedAt = asString(updated.arrivedAt) || iso;
      updated.statusHistory = appendStatusHistory(updated, updated.status, iso, actor);
      await createNotification({
        userId: updated.customerId,
        userType: 'customer',
        title: 'Please confirm receiving your order',
        subtitle: `${updated.cookName || 'Cook'} is ready. Please confirm you received the order.`,
        type: 'order',
        data: { orderId: updated.id, status: updated.status },
      });
      return { order: updated };
    }

    case 'confirm_received': {
      if (order.status === 'delivered') {
        return { order };
      }
      const error = ensureStatus(order, [
        'ready_for_pickup',
        'out_for_delivery',
        'awaiting_customer_confirmation',
      ], action);
      if (error) return { error };
      updated.status = 'delivered';
      updated.deliveredAt = asString(updated.deliveredAt) || iso;
      updated.confirmedReceivedAt = asString(updated.confirmedReceivedAt) || iso;
      updated.payoutId = await createPayout(updated, iso);
      updated.statusHistory = appendStatusHistory(updated, updated.status, iso, actor);
      await incrementCookDeliveredStats(updated.cookId, iso);
      await incrementDishDeliveredStats(updated, iso);
      await createNotification({
        userId: updated.cookId,
        userType: 'cook',
        title: 'Payout created',
        subtitle: `SAR ${asNumber(updated.cookEarnings, 0).toFixed(2)} is pending transfer.`,
        type: 'payout',
        data: {
          orderId: updated.id,
          payoutId: updated.payoutId,
          amount: asNumber(updated.cookEarnings, 0),
        },
      });
      return { order: updated };
    }

    case 'nudge_late': {
      const error = ensureStatus(
        order,
        ['ready_for_pickup', 'out_for_delivery', 'awaiting_customer_confirmation'],
        action,
      );
      if (error) return { error };
      const dueAt = Date.parse(asString(order.deliveryDueAt));
      if (!Number.isFinite(dueAt) || Date.parse(iso) < dueAt) {
        return {
          error: response(409, { message: 'Order is not late yet.', order }),
        };
      }
      const lastNudged = Date.parse(asString(order.lastNudgedAt));
      if (
        Number.isFinite(lastNudged) &&
        Date.parse(iso) - lastNudged < NUDGE_COOLDOWN_MINUTES * 60 * 1000
      ) {
        return {
          error: response(409, { message: 'Late nudge cooldown is still active.', order }),
        };
      }
      updated.lastNudgedAt = iso;
      updated.nudgeCount = asInt(updated.nudgeCount, 0) + 1;
      updated.statusHistory = appendStatusHistory(
        updated,
        updated.status,
        iso,
        actor,
        'late_nudge',
      );
      await createNotification({
        userId: updated.cookId,
        userType: 'cook',
        title: 'Customer says the order has not arrived',
        subtitle: `${updated.customerName || 'Customer'} nudged order ${updated.displayId || updated.id}.`,
        type: 'order',
        data: { orderId: updated.id, action: action, nudgeCount: updated.nudgeCount },
      });
      return { order: updated };
    }

    case 'report_not_received': {
      const error = ensureStatus(
        order,
        ['ready_for_pickup', 'out_for_delivery', 'awaiting_customer_confirmation'],
        action,
      );
      if (error) return { error };
      updated.status = 'issue_reported';
      updated.issueReason = asString(body.issueReason || body.reason, 'Customer reports order not received.');
      updated.statusHistory = appendStatusHistory(updated, updated.status, iso, actor);
      await createNotification({
        userId: updated.cookId,
        userType: 'cook',
        title: '⚠️ Customer did not receive the order',
        subtitle: `${updated.customerName || 'Customer'} reported that order ${updated.displayId || updated.id} was not received.`,
        type: 'order',
        data: { orderId: updated.id, status: updated.status },
      });
      return { order: updated };
    }

    case 'report_issue': {
      const error = ensureStatus(
        order,
        ['in_progress', 'ready_for_pickup', 'out_for_delivery', 'awaiting_customer_confirmation'],
        action,
      );
      if (error) return { error };
      updated.status = 'issue_reported';
      updated.issueReason = asString(body.issueReason || body.reason, 'Order issue reported.');
      updated.statusHistory = appendStatusHistory(updated, updated.status, iso, actor);
      await createNotification({
        userId: updated.customerId,
        userType: 'customer',
        title: 'Issue reported with your order',
        subtitle: updated.issueReason,
        type: 'order',
        data: { orderId: updated.id, status: updated.status },
      });
      return { order: updated };
    }

    case 'resolve_issue': {
      const error = ensureStatus(order, ['issue_reported'], action);
      if (error) return { error };
      updated.status = 'awaiting_customer_confirmation';
      updated.statusHistory = appendStatusHistory(updated, updated.status, iso, actor, 'issue_resolved');
      await createNotification({
        userId: updated.customerId,
        userType: 'customer',
        title: '✅ Issue resolved',
        subtitle: `${updated.cookName || 'Cook'} resolved the issue. Please confirm you received the order.`,
        type: 'order',
        data: { orderId: updated.id, status: updated.status },
      });
      return { order: updated };
    }

    case 'finish_order': {
      const error = ensureStatus(order, ['awaiting_customer_confirmation'], action);
      if (error) return { error };
      updated.status = 'delivered';
      updated.deliveredAt = asString(updated.deliveredAt) || iso;
      updated.confirmedReceivedAt = asString(updated.confirmedReceivedAt) || iso;
      updated.payoutId = await createPayout(updated, iso);
      updated.statusHistory = appendStatusHistory(updated, updated.status, iso, actor);
      await incrementCookDeliveredStats(updated.cookId, iso);
      await incrementDishDeliveredStats(updated, iso);
      await createNotification({
        userId: updated.customerId,
        userType: 'customer',
        title: 'Order completed',
        subtitle: `Your order ${updated.displayId || updated.id} has been completed. Thank you!`,
        type: 'order',
        data: { orderId: updated.id, status: updated.status },
      });
      await createNotification({
        userId: updated.cookId,
        userType: 'cook',
        title: 'Payout created',
        subtitle: `SAR ${asNumber(updated.cookEarnings, 0).toFixed(2)} is pending transfer.`,
        type: 'payout',
        data: {
          orderId: updated.id,
          payoutId: updated.payoutId,
          amount: asNumber(updated.cookEarnings, 0),
        },
      });
      return { order: updated };
    }

    case 'request_replacement': {
      const error = ensureStatus(order, ['issue_reported'], action);
      if (error) return { error };
      const replacementItems = normalizeReplacementItems(body.replacementItems || body.items);
      if (!replacementItems.length) {
        return {
          error: response(400, { message: 'replacementItems are required.' }),
        };
      }
      updated = applyReplacementItems(updated, replacementItems);
      updated.status = 'replacement_pending_cook';
      const replacementEntry = {
        id: `replacement_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
        status: 'pending_cook',
        requestedAt: iso,
        requestedBy: actor,
        reason: asString(body.reason || body.issueReason || updated.issueReason),
        items: replacementItems,
      };
      updated.replacementHistory = [
        ...(Array.isArray(updated.replacementHistory) ? updated.replacementHistory : []),
        replacementEntry,
      ];
      updated.statusHistory = appendStatusHistory(updated, updated.status, iso, actor);
      await createNotification({
        userId: updated.cookId,
        userType: 'cook',
        title: 'Replacement requested',
        subtitle: `${updated.customerName || 'Customer'} requested a replacement order.`,
        type: 'order',
        data: { orderId: updated.id, status: updated.status },
      });
      return { order: updated };
    }

    case 'approve_replacement': {
      const error = ensureStatus(order, ['replacement_pending_cook'], action);
      if (error) return { error };
      updated.status = 'in_progress';
      updated.acceptedAt = asString(updated.acceptedAt) || iso;
      updated.deliveryDueAt = addMinutes(
        iso,
        asInt(updated.prepEstimateMinutes, DEFAULT_PREP_MINUTES) + DELIVERY_BUFFER_MINUTES,
      );
      updated.replacementHistory = (Array.isArray(updated.replacementHistory)
        ? updated.replacementHistory
        : []
      ).map((entry, index, list) =>
        index === list.length - 1 && entry.status === 'pending_cook'
          ? { ...entry, status: 'approved', approvedAt: iso }
          : entry,
      );
      updated.statusHistory = appendStatusHistory(updated, updated.status, iso, actor);
      await createNotification({
        userId: updated.customerId,
        userType: 'customer',
        title: 'Replacement approved',
        subtitle: `${updated.cookName || 'Cook'} approved the replacement.`,
        type: 'order',
        data: { orderId: updated.id, status: updated.status },
      });
      return { order: updated };
    }

    case 'rate': {
      const error = ensureStatus(order, ['delivered'], action);
      if (error) return { error };
      const cookRating = clampInt(body.cookRating ?? body.rating, 1, 5);
      const serviceRating = clampInt(body.serviceRating ?? body.rating, 1, 5);
      updated.cookRating = cookRating;
      updated.serviceRating = serviceRating;
      updated.rating = cookRating;
      updated.reviewComment = asString(body.reviewComment);
      updated.ratedAt = iso;
      await updateCookRatingStats(updated.cookId, cookRating, iso);
      return { order: updated };
    }

    case 'direct_delivered':
      return {
        error: response(400, {
          message: 'Use action confirm_received after customer confirmation to deliver an order.',
        }),
      };

    default:
      return { error: response(400, { message: 'Provide a valid order action.' }) };
  }
}

exports.handler = async (event) => {
  const method =
    asString(event?.requestContext?.http?.method || event?.httpMethod).toUpperCase();
  if (method === 'OPTIONS') {
    return response(200, { ok: true });
  }
  if (method !== 'POST' && method !== 'PUT') {
    return response(405, { message: 'Method not allowed.' });
  }

  try {
    const orderId = asString(event?.pathParameters?.id || event?.pathParameters?.orderId);
    if (!orderId) {
      return response(400, { message: 'Missing order id in path.' });
    }

    const body = parseBody(event);
    const existing = await getOrder(orderId);
    if (!existing.order) {
      return response(404, { message: 'Order not found.', id: orderId });
    }

    const action = deriveAction(body, existing.order.status);
    const result = await handleAction(existing.order, action, body, nowIso());
    if (result.error) return result.error;

    const updated = result.order;
    if (updated !== existing.order) {
      await putOrder(updated);
    }
    return response(200, { order: updated });
  } catch (error) {
    console.error('ordersUpdateStatus error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
