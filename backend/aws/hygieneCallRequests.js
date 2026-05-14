const { 
  DynamoDBClient, 
  PutItemCommand, 
  QueryCommand,
  UpdateItemCommand,
  ScanCommand
} = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});
const TABLE = process.env.HYGIENE_CALLS_TABLE || 'hygienes';

const JSON_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'OPTIONS,GET,POST,PUT',
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

function mapCallRequest(item) {
  if (!item) return null;
  return {
    id: pickString(item.id),
    cookId: pickString(item.cookId),
    cookName: pickString(item.cookName),
    adminId: pickString(item.adminId),
    adminName: pickString(item.adminName),
    requestedAt: pickString(item.requestedAt),
    status: pickString(item.status),
    respondedAt: pickString(item.respondedAt),
    createdAt: pickString(item.createdAt),
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

function extractRequestId(event) {
  const fromPath = event?.pathParameters?.id;
  if (fromPath) return fromPath;
  const rawPath = event?.rawPath || event?.path || '';
  const segments = rawPath.split('/').filter(Boolean);
  if (segments.length >= 3) {
    return segments[segments.length - 1];
  }
  return null;
}

// Helper: find an item by id (partition key) using Query.
// Returns the first matching item (with its createdAt sort key).
async function findItemById(id) {
  const result = await ddb.send(new QueryCommand({
    TableName: TABLE,
    KeyConditionExpression: 'id = :id',
    ExpressionAttributeValues: { ':id': { S: id } },
    Limit: 1,
  }));
  return (result.Items && result.Items.length > 0) ? result.Items[0] : null;
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
    // ── POST: Create new call request ──────────────────────────────────
    if (method === 'POST') {
      const body = parseBody(event);
      const { id, cookId, cookName, adminId, adminName } = body;

      if (!id || !cookId) {
        return resp(400, { message: 'Missing required fields: id, cookId.' });
      }

      const now = new Date().toISOString();
      const item = {
        id: { S: id },
        createdAt: { S: now },
        cookId: { S: cookId },
        cookName: { S: cookName || '' },
        adminId: { S: adminId || '' },
        adminName: { S: adminName || '' },
        requestedAt: { S: body.requestedAt || now },
        status: { S: 'pending' },
        recordType: { S: 'call_request' },
      };

      await ddb.send(new PutItemCommand({ TableName: TABLE, Item: item }));

      return resp(201, {
        message: 'Call request created.',
        request: {
          id, cookId,
          cookName: cookName || '',
          adminId: adminId || '',
          adminName: adminName || '',
          requestedAt: item.requestedAt.S,
          status: 'pending',
          createdAt: now,
        },
      });
    }

    // ── PUT: Update call request status ────────────────────────────────
    if (method === 'PUT') {
      const requestId = extractRequestId(event);
      const body = parseBody(event);
      const { status } = body;

      if (!requestId || !status) {
        return resp(400, { message: 'Missing requestId or status.' });
      }

      // Find the item first to get the createdAt sort key
      const existing = await findItemById(requestId);
      if (!existing) {
        return resp(404, { message: 'Call request not found.', requestId });
      }

      const createdAt = existing.createdAt;
      const result = await ddb.send(new UpdateItemCommand({
        TableName: TABLE,
        Key: {
          id: { S: requestId },
          createdAt: createdAt,
        },
        UpdateExpression: 'SET #s = :s, respondedAt = :r, updatedAt = :u',
        ExpressionAttributeNames: { '#s': 'status' },
        ExpressionAttributeValues: {
          ':s': { S: status },
          ':r': { S: new Date().toISOString() },
          ':u': { S: new Date().toISOString() },
        },
        ReturnValues: 'ALL_NEW',
      }));

      return resp(200, {
        message: 'Status updated.',
        request: mapCallRequest(result.Attributes),
      });
    }

    // ── GET: Fetch call request(s) ────────────────────────────────────
    if (method === 'GET') {
      const requestId = extractRequestId(event);

      if (requestId && requestId !== 'call-requests') {
        // Get by ID using Query (since we need both keys)
        const item = await findItemById(requestId);
        if (!item) {
          return resp(404, { message: 'Request not found.' });
        }
        return resp(200, { request: mapCallRequest(item) });
      }

      // List pending requests for a cook
      const cookId = event?.queryStringParameters?.cookId;
      if (cookId) {
        const result = await ddb.send(new ScanCommand({
          TableName: TABLE,
          FilterExpression: 'cookId = :c AND #s = :s AND recordType = :rt',
          ExpressionAttributeNames: { '#s': 'status' },
          ExpressionAttributeValues: {
            ':c': { S: cookId },
            ':s': { S: 'pending' },
            ':rt': { S: 'call_request' },
          },
        }));
        const requests = (result.Items || []).map(mapCallRequest).filter(Boolean);
        return resp(200, { requests });
      }

      return resp(400, { message: 'Provide cookId query parameter or request ID in path.' });
    }

    return resp(405, { message: 'Method not allowed.' });
  } catch (error) {
    console.error('hygieneCallRequests error:', error);
    return resp(500, { message: 'Internal server error.', error: error.message });
  }
};
