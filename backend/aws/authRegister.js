const {
  DynamoDBClient,
  PutItemCommand,
  QueryCommand,
  ScanCommand,
} = require('@aws-sdk/client-dynamodb');
const crypto = require('crypto');

const ddb = new DynamoDBClient({});
const USERS_TABLE = process.env.USERS_TABLE;
const FALLBACK_TABLES = ['users', 'naham_users'];
const JSON_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'OPTIONS,POST',
};

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

function buildStableUserId(emailLower) {
  const digest = crypto.createHash('sha256').update(emailLower).digest('hex');
  return `user_${digest.slice(0, 32)}`;
}

function response(statusCode, payload) {
  return {
    statusCode,
    headers: JSON_HEADERS,
    body: JSON.stringify(payload),
  };
}

function parseBody(event) {
  if (!event || event.body == null) {
    return {};
  }
  if (typeof event.body === 'string') {
    try {
      return JSON.parse(event.body || '{}');
    } catch (_) {
      throw new Error('Invalid JSON body.');
    }
  }
  if (typeof event.body === 'object') {
    return event.body;
  }
  throw new Error('Unsupported request body type.');
}

function isMissingEmailIndex(error) {
  const message = (error?.message || '').toLowerCase();
  return message.includes('does not have the specified index');
}

async function findUsersByEmail(email) {
  const tableNames = Array.from(
    new Set([USERS_TABLE, ...FALLBACK_TABLES].filter(Boolean)),
  );

  let anyTableReached = false;
  for (const tableName of tableNames) {
    try {
      anyTableReached = true;
      const result = await ddb.send(
        new QueryCommand({
          TableName: tableName,
          IndexName: 'email-index',
          KeyConditionExpression: 'email = :email',
          ExpressionAttributeValues: {
            ':email': { S: email },
          },
        }),
      );
      const items = result.Items ?? [];
      if (items.length > 0) {
        return items;
      }
      const scan = await ddb.send(
        new ScanCommand({
          TableName: tableName,
          FilterExpression: 'email = :email',
          ExpressionAttributeValues: {
            ':email': { S: email },
          },
          ConsistentRead: true,
          Limit: 25,
        }),
      );
      const scannedItems = scan.Items ?? [];
      if (scannedItems.length > 0) {
        return scannedItems;
      }
      continue;
    } catch (error) {
      if (!isMissingEmailIndex(error)) {
        const code = (error?.name || '').toLowerCase();
        if (code.includes('resourcenotfound')) {
          continue;
        }
        continue;
      }

      anyTableReached = true;
      try {
        const scan = await ddb.send(
          new ScanCommand({
            TableName: tableName,
            FilterExpression: 'email = :email',
            ExpressionAttributeValues: {
              ':email': { S: email },
            },
            ConsistentRead: true,
            Limit: 25,
          }),
        );
        const items = scan.Items ?? [];
        if (items.length > 0) {
          return items;
        }
      } catch (scanError) {
        const code = (scanError?.name || '').toLowerCase();
        if (!code.includes('resourcenotfound')) {
          throw scanError;
        }
      }
    }
  }

  if (!anyTableReached) {
    throw new Error('Unable to query any users table.');
  }

  return [];
}

async function putUserWithFallbacks(item, {enforceUniqueId = false} = {}) {
  const tableNames = Array.from(
    new Set([USERS_TABLE, ...FALLBACK_TABLES].filter(Boolean)),
  );

  let lastError = null;
  for (const tableName of tableNames) {
    try {
      const params = { TableName: tableName, Item: item };
      if (enforceUniqueId) {
        params.ConditionExpression = 'attribute_not_exists(id)';
      }
      await ddb.send(new PutItemCommand(params));
      return true;
    } catch (error) {
      if (
        enforceUniqueId &&
        error?.name === 'ConditionalCheckFailedException'
      ) {
        return false;
      }
      const code = (error?.name || '').toLowerCase();
      if (code.includes('resourcenotfound')) {
        lastError = error;
        continue;
      }
      throw error;
    }
  }

  if (lastError) {
    throw lastError;
  }
  throw new Error('No writable users table was found.');
}

exports.handler = async (event) => {
  if (event?.requestContext?.http?.method === 'OPTIONS') {
    return response(200, { ok: true });
  }

  if (!USERS_TABLE) {
    return response(500, {
      message: 'Server misconfiguration: USERS_TABLE is not set.',
    });
  }

  try {
    const body = parseBody(event);
    const name = (body.name || '').toString().trim();
    const email = (body.email || '').toString().trim();
    const password = (body.password || '').toString();
    const role = (body.role || '').toString().trim().toLowerCase();
    const phone = body.phone == null ? '' : body.phone.toString().trim();

    if (!name || !email || !password || !role) {
      return response(400, { message: 'Missing required fields.' });
    }

    const emailLower = email.toLowerCase();

    const existing = await findUsersByEmail(emailLower);
    if (existing.length > 0) {
      return response(409, { message: 'Email already exists.' });
    }

    const hashedPassword = hashPassword(password);
    const now = new Date().toISOString();
    const stableUserId = buildStableUserId(emailLower);

    const item = {
      id: { S: stableUserId },
      name: { S: name },
      email: { S: emailLower },
      passwordHash: { S: hashedPassword },
      phone: { S: phone },
      role: { S: role },
      createdAt: { S: now },
    };

    const inserted = await putUserWithFallbacks(item, {enforceUniqueId: true});
    if (!inserted) {
      return response(409, { message: 'Email already exists.' });
    }

    return response(200, {
      user: {
        id: stableUserId,
        name,
        email: emailLower,
        phone,
        role,
        createdAt: now,
      },
      accessToken: stableUserId,
      refreshToken: stableUserId,
    });
  } catch (error) {
    console.error('authRegister error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
