const { DynamoDBClient, ScanCommand } = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});
const TABLE_NAME = process.env.PAYOUTS_TABLE || 'payouts';

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

function pickString(attrValue, fallback = '') {
  return typeof attrValue?.S === 'string' ? attrValue.S : fallback;
}

function pickNumber(attrValue, fallback = 0) {
  const raw = attrValue?.N;
  if (typeof raw !== 'string') return fallback;
  return asNumber(raw, fallback);
}

function toPayout(item) {
  return {
    id: pickString(item.id),
    orderId: pickString(item.orderId),
    cookId: pickString(item.cookId),
    cookName: pickString(item.cookName),
    customerId: pickString(item.customerId),
    amount: pickNumber(item.amount, 0),
    currency: pickString(item.currency, 'SAR'),
    status: pickString(item.status, 'pending_transfer'),
    createdAt: pickString(item.createdAt),
    updatedAt: pickString(item.updatedAt),
  };
}

exports.handler = async (event) => {
  const method =
    asString(event?.requestContext?.http?.method || event?.httpMethod).toUpperCase();
  if (method === 'OPTIONS') {
    return response(200, { ok: true });
  }
  if (method && method !== 'GET') {
    return response(405, { message: 'Method not allowed.' });
  }

  try {
    const query = event?.queryStringParameters || {};
    const cookId = asString(query.cookId);
    if (!cookId) {
      return response(400, { message: 'cookId is required.' });
    }

    const result = await ddb.send(
      new ScanCommand({
        TableName: TABLE_NAME,
        FilterExpression: '#cookId = :cookId',
        ExpressionAttributeNames: {
          '#cookId': 'cookId',
        },
        ExpressionAttributeValues: {
          ':cookId': { S: cookId },
        },
      }),
    );
    const payouts = (result.Items || [])
      .map(toPayout)
      .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
    const totalPending = payouts
      .filter((item) => item.status === 'pending_transfer')
      .reduce((sum, item) => sum + item.amount, 0);

    return response(200, {
      payouts,
      count: payouts.length,
      totalPending,
    });
  } catch (error) {
    console.error('payoutsList error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
