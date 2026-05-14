const { randomUUID } = require('node:crypto');
const { DynamoDBClient, PutItemCommand } = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});
const TABLE_NAME = process.env.NOTIFICATIONS_TABLE || 'notifications';
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
  if (!event || event.body == null || event.body === '') {
    return {};
  }
  if (typeof event.body === 'object') {
    return event.body;
  }
  try {
    return JSON.parse(event.body);
  } catch (_) {
    throw new Error('Invalid JSON body.');
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

function notificationToItem(notification) {
  return Object.fromEntries(
    Object.entries(notification).map(([key, value]) => [key, valueToAttr(value)]),
  );
}

exports.handler = async (event) => {
  if (event?.requestContext?.http?.method === 'OPTIONS') {
    return response(200, { ok: true });
  }

  try {
    const body = parseBody(event);
    const userId = String(body.userId || '').trim();
    const userType = String(body.userType || '').trim();
    const title = String(body.title || '').trim();

    if (!userId || !userType || !title) {
      return response(400, {
        message: 'userId, userType, and title are required.',
      });
    }

    const notification = {
      id: randomUUID(),
      userId,
      userType,
      title,
      subtitle: String(body.subtitle || ''),
      type: String(body.type || 'general'),
      data: body.data && typeof body.data === 'object' ? body.data : {},
      isRead: false,
      createdAt: new Date().toISOString(),
    };

    await ddb.send(
      new PutItemCommand({
        TableName: TABLE_NAME,
        Item: notificationToItem(notification),
      }),
    );

    return response(201, { notification });
  } catch (error) {
    console.error('Error saving notification:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
