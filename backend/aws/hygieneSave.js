const { DynamoDBClient, PutItemCommand } = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});
const TABLE = process.env.HYGIENE_TABLE || 'hygienes';

const JSON_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'OPTIONS,POST',
};

function resp(statusCode, payload) {
  return {
    statusCode,
    headers: JSON_HEADERS,
    body: JSON.stringify(payload),
  };
}

function parseBody(event) {
  if (!event || event.body == null) return {};
  if (typeof event.body === 'string') {
    try { return JSON.parse(event.body || '{}'); }
    catch (_) { return {}; }
  }
  if (typeof event.body === 'object') return event.body;
  return {};
}

exports.handler = async (event) => {
  const method = (
    event?.requestContext?.http?.method ||
    event?.httpMethod ||
    ''
  ).toUpperCase();

  if (method === 'OPTIONS') {
    return resp(200, { ok: true });
  }

  try {
    const body = parseBody(event);
    const {
      id,
      cookId,
      cookName,
      decision,
      inspectedAt,
      callDurationSeconds,
      adminId,
      adminName,
      note
    } = body;

    if (!id || !cookId || !decision) {
      return resp(400, { message: 'Missing required fields: id, cookId, decision.' });
    }

    const now = new Date().toISOString();
    const item = {
      id: { S: id },
      createdAt: { S: now },
      cookId: { S: cookId },
      cookName: { S: cookName || '' },
      decision: { S: decision },
      inspectedAt: { S: inspectedAt || now },
      callDurationSeconds: { N: String(callDurationSeconds || 0) },
      adminId: { S: adminId || 'admin_unknown' },
      adminName: { S: adminName || 'System Admin' },
      note: { S: note || '' },
      recordType: { S: 'inspection' },
    };

    await ddb.send(new PutItemCommand({ TableName: TABLE, Item: item }));

    return resp(200, {
      message: 'Record saved successfully.',
      record: {
        id, cookId,
        cookName: cookName || '',
        decision,
        inspectedAt: item.inspectedAt.S,
        callDurationSeconds: callDurationSeconds || 0,
        adminId: adminId || 'admin_unknown',
        adminName: adminName || 'System Admin',
        note: note || '',
        createdAt: now,
      },
    });
  } catch (error) {
    console.error('hygieneSave error:', error);
    return resp(500, { message: 'Internal server error.', error: error.message });
  }
};
