const { DynamoDBClient, ScanCommand } = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});
const TABLE_NAME = process.env.NOTIFICATIONS_TABLE || 'notifications';
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
    const userId = String(event?.queryStringParameters?.userId || '').trim();
    const userType = String(event?.queryStringParameters?.userType || '').trim();

    if (!userId || !userType) {
      return response(400, { message: 'userId and userType are required.' });
    }

    const result = await ddb.send(
      new ScanCommand({
        TableName: TABLE_NAME,
        FilterExpression: 'userId = :userId AND userType = :userType',
        ExpressionAttributeValues: {
          ':userId': { S: userId },
          ':userType': { S: userType },
        },
      }),
    );

    const notifications = (result.Items || [])
      .map(itemToMap)
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    return response(200, { notifications });
  } catch (error) {
    console.error('Error fetching notifications:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
