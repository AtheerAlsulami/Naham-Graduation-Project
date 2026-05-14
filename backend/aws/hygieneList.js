const { DynamoDBClient, ScanCommand } = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});
const TABLE = process.env.HYGIENE_TABLE || 'hygienes';

const JSON_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'OPTIONS,GET',
};

function resp(statusCode, payload) {
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

function mapRecord(item) {
  return {
    id: pickString(item.id),
    cookId: pickString(item.cookId),
    cookName: pickString(item.cookName),
    decision: pickString(item.decision),
    inspectedAt: pickString(item.inspectedAt),
    callDurationSeconds: Math.round(pickNumber(item.callDurationSeconds, 0)),
    adminId: pickString(item.adminId),
    adminName: pickString(item.adminName),
    note: pickString(item.note),
    createdAt: pickString(item.createdAt),
  };
}

exports.handler = async (event) => {
  if (event?.requestContext?.http?.method === 'OPTIONS') {
    return resp(200, { ok: true });
  }

  try {
    const cookId = event?.queryStringParameters?.cookId;
    const limit = parseInt(event?.queryStringParameters?.limit || '50', 10);

    // Only return inspection records (not call_request records)
    // Records with recordType='inspection' OR records without recordType
    // (for backward compatibility with records created before recordType was added)
    let filterExpression = '(attribute_not_exists(recordType) OR recordType = :rt)';
    const expressionValues = {
      ':rt': { S: 'inspection' },
    };

    if (cookId) {
      filterExpression += ' AND cookId = :cookId';
      expressionValues[':cookId'] = { S: cookId };
    }

    const result = await ddb.send(new ScanCommand({
      TableName: TABLE,
      FilterExpression: filterExpression,
      ExpressionAttributeValues: expressionValues,
      Limit: limit,
    }));

    const items = result.Items || [];
    const records = items.map(mapRecord).sort((a, b) =>
      new Date(b.inspectedAt) - new Date(a.inspectedAt)
    );

    return resp(200, { records });
  } catch (error) {
    console.error('hygieneList error:', error);
    return resp(500, { message: 'Internal server error.', error: error.message });
  }
};
