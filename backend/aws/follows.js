const {
  DynamoDBClient,
  DeleteItemCommand,
  PutItemCommand,
  QueryCommand,
  ScanCommand,
  UpdateItemCommand,
} = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});
const FOLLOWS_TABLE = process.env.FOLLOWS_TABLE || 'follows';
const USERS_TABLE = process.env.USERS_TABLE || 'users';

const FOLLOWS_FALLBACKS = [FOLLOWS_TABLE, 'naham_follows', 'naham-follows'].filter(Boolean);
const USERS_FALLBACKS = [USERS_TABLE, 'naham_users', 'naham-users'].filter(Boolean);

const JSON_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'OPTIONS,GET,POST,DELETE',
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
  return {};
}

function pickString(val) {
  if (val?.S == null) return '';
  return String(val.S).trim();
}

function followId(customerId, cookId) {
  return `${customerId}__${cookId}`;
}

async function updateUserCounter(userId, fieldName, delta) {
  if (!userId) return;
  for (const tableName of USERS_FALLBACKS) {
    try {
      await ddb.send(
        new UpdateItemCommand({
          TableName: tableName,
          Key: { id: { S: userId } },
          UpdateExpression:
            'SET #updatedAt = :updatedAt, #counter = if_not_exists(#counter, :zero) + :delta',
          ConditionExpression:
            delta < 0 ? 'attribute_exists(#counter) AND #counter >= :one' : undefined,
          ExpressionAttributeNames: {
            '#updatedAt': 'updatedAt',
            '#counter': fieldName,
          },
          ExpressionAttributeValues: {
            ':zero': { N: '0' },
            ':one': { N: '1' },
            ':delta': { N: String(delta) },
            ':updatedAt': { S: new Date().toISOString() },
          },
        }),
      );
      return;
    } catch (error) {
      const code = String(error?.name || '').toLowerCase();
      if (code.includes('conditionalcheckfailed')) return;
      if (code.includes('resourcenotfound')) continue;
      throw error;
    }
  }
}

async function createFollow(customerId, cookId) {
  console.log(`Creating follow: ${customerId} -> ${cookId}`);
  const now = new Date().toISOString();
  let lastError = null;
  let succeeded = false;

  for (const tableName of FOLLOWS_FALLBACKS) {
    try {
      await ddb.send(
        new PutItemCommand({
          TableName: tableName,
          Item: {
            id: { S: followId(customerId, cookId) },
            customerId: { S: customerId },
            cookId: { S: cookId },
            createdAt: { S: now },
          },
          ConditionExpression: 'attribute_not_exists(id)',
        }),
      );
      console.log(`Successfully created follow in table: ${tableName}`);
      succeeded = true;
      lastError = null;
      break;
    } catch (error) {
      const code = String(error?.name || '').toLowerCase();
      if (code.includes('conditionalcheckfailed')) {
        console.log(`Follow already exists: ${customerId} -> ${cookId}`);
        return; // Already followed, nothing to update
      }
      if (code.includes('resourcenotfound')) {
        lastError = error;
        continue;
      }
      throw error;
    }
  }

  if (!succeeded && lastError) throw lastError;

  if (succeeded) {
    await updateUserCounter(customerId, 'followingCooksCount', 1);
    await updateUserCounter(cookId, 'followersCount', 1);
  }
}

async function deleteFollow(customerId, cookId) {
  console.log(`Deleting follow: ${customerId} -> ${cookId}`);
  let lastError = null;
  let succeeded = false;

  for (const tableName of FOLLOWS_FALLBACKS) {
    try {
      await ddb.send(
        new DeleteItemCommand({
          TableName: tableName,
          Key: { id: { S: followId(customerId, cookId) } },
          ConditionExpression: 'attribute_exists(id)',
        }),
      );
      console.log(`Successfully deleted follow from table: ${tableName}`);
      succeeded = true;
      lastError = null;
      break;
    } catch (error) {
      const code = String(error?.name || '').toLowerCase();
      if (code.includes('conditionalcheckfailed')) {
        console.log(`Follow did not exist, nothing to delete: ${customerId} -> ${cookId}`);
        return; // Not followed, nothing to update
      }
      if (code.includes('resourcenotfound')) {
        lastError = error;
        continue;
      }
      throw error;
    }
  }

  if (!succeeded && lastError) throw lastError;

  if (succeeded) {
    await updateUserCounter(customerId, 'followingCooksCount', -1);
    await updateUserCounter(cookId, 'followersCount', -1);
  }
}

async function listFollows(customerId) {
  console.log(`Listing follows for customer: ${customerId}`);
  let lastError = null;
  for (const tableName of FOLLOWS_FALLBACKS) {
    try {
      // Try Query first
      try {
        console.log(`Trying query on table: ${tableName}`);
        const result = await ddb.send(
          new QueryCommand({
            TableName: tableName,
            IndexName: 'customerId-index',
            KeyConditionExpression: '#customerId = :customerId',
            ExpressionAttributeNames: { '#customerId': 'customerId' },
            ExpressionAttributeValues: { ':customerId': { S: customerId } },
          }),
        );
        console.log(`Query succeeded, found ${result.Items?.length || 0} items.`);
        return (result.Items || []).map((item) => ({
          id: pickString(item.id),
          customerId: pickString(item.customerId),
          cookId: pickString(item.cookId),
          createdAt: pickString(item.createdAt),
        }));
      } catch (queryError) {
        console.warn(`Query failed for ${tableName}, falling back to Scan:`, queryError.message);
        // Fallback to Scan if index is missing
        const result = await ddb.send(
          new ScanCommand({
            TableName: tableName,
            FilterExpression: '#customerId = :customerId',
            ExpressionAttributeNames: { '#customerId': 'customerId' },
            ExpressionAttributeValues: { ':customerId': { S: customerId } },
            Limit: 100, // Safety limit
          }),
        );
        console.log(`Scan succeeded, found ${result.Items?.length || 0} items.`);
        return (result.Items || []).map((item) => ({
          id: pickString(item.id),
          customerId: pickString(item.customerId),
          cookId: pickString(item.cookId),
          createdAt: pickString(item.createdAt),
        }));
      }
    } catch (error) {
      const code = String(error?.name || '').toLowerCase();
      if (code.includes('resourcenotfound')) {
        console.warn(`Table ${tableName} not found, trying next fallback.`);
        lastError = error;
        continue;
      }
      throw error;
    }
  }
  if (lastError) throw lastError;
  return [];
}

exports.handler = async (event) => {
  const method = asString(event?.requestContext?.http?.method || event?.httpMethod).toUpperCase();
  const path = asString(event?.path || event?.requestContext?.http?.path);
  if (method === 'OPTIONS') return response(200, { ok: true });

  try {
    const body = parseBody(event);
    const query = event?.queryStringParameters || {};
    const customerId = asString(body.customerId || query.customerId);
    const cookId = asString(body.cookId || query.cookId);

    if (!customerId) return response(400, { message: 'Missing customerId' });

    if (method === 'GET') {
      const items = await listFollows(customerId);
      return response(200, { items });
    }

    if (!cookId) return response(400, { message: 'Missing cookId' });

    if (method === 'POST') {
      await createFollow(customerId, cookId);
      return response(200, { followed: true });
    }

    if (method === 'DELETE') {
      await deleteFollow(customerId, cookId);
      return response(200, { followed: false });
    }

    return response(405, { message: 'Method not allowed' });
  } catch (error) {
    console.error('Error:', error);
    return response(500, {
      message: 'Internal server error',
      error: String(error.message || error),
      diagnostics: { method, path }
    });
  }
};
