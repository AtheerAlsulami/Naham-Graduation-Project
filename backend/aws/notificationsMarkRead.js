const { DynamoDBClient, UpdateItemCommand } = require('@aws-sdk/client-dynamodb');

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
    return {};
  }
}

function pickNotificationId(event) {
  const queryId = event?.queryStringParameters?.notificationId;
  const bodyId = parseBody(event).notificationId;
  return String(queryId || bodyId || '').trim();
}

function attrToValue(attr) {
  if (!attr || typeof attr !== 'object') return null;
  if ('S' in attr) return attr.S;
  if ('BOOL' in attr) return attr.BOOL;
  if ('N' in attr) return Number(attr.N);
  if ('NULL' in attr) return null;
  if ('M' in attr) {
    return Object.fromEntries(
      Object.entries(attr.M).map(([key, value]) => [key, attrToValue(value)]),
    );
  }
  if ('L' in attr) return attr.L.map(attrToValue);
  return null;
}

function itemToMap(item) {
  return Object.fromEntries(
    Object.entries(item || {}).map(([key, value]) => [key, attrToValue(value)]),
  );
}

exports.handler = async (event) => {
  if (event?.requestContext?.http?.method === 'OPTIONS') {
    return response(200, { ok: true });
  }

  try {
    const notificationId = pickNotificationId(event);
    if (!notificationId) {
      return response(400, { message: 'notificationId is required.' });
    }

    const result = await ddb.send(
      new UpdateItemCommand({
        TableName: TABLE_NAME,
        Key: { id: { S: notificationId } },
        UpdateExpression: 'SET isRead = :isRead',
        ExpressionAttributeValues: {
          ':isRead': { BOOL: true },
        },
        ReturnValues: 'ALL_NEW',
      }),
    );

    return response(200, { notification: itemToMap(result.Attributes) });
  } catch (error) {
    console.error('Error marking notification as read:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
