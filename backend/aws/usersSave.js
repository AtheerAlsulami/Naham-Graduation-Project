const {
  DynamoDBClient,
  PutItemCommand,
  QueryCommand,
  ScanCommand,
} = require('@aws-sdk/client-dynamodb');
const crypto = require('crypto');

const ddb = new DynamoDBClient({});
const USERS_TABLE = process.env.USERS_TABLE;
const ENV_FALLBACK_TABLES = String(process.env.USERS_FALLBACK_TABLES || '')
  .split(',')
  .map((table) => table.trim())
  .filter(Boolean);
const DEFAULT_FALLBACK_TABLES = ['users', 'naham_users'];
const FALLBACK_TABLES = Array.from(
  new Set([USERS_TABLE, ...ENV_FALLBACK_TABLES, ...DEFAULT_FALLBACK_TABLES]),
);
const DEFAULT_TEMP_PASSWORD = String(
  process.env.ADMIN_DEFAULT_USER_PASSWORD || '',
).trim();
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
  if (!event || event.body == null) return {};
  if (typeof event.body === 'string') {
    try {
      return JSON.parse(event.body || '{}');
    } catch (_) {
      throw new Error('Invalid JSON body.');
    }
  }
  if (typeof event.body === 'object') return event.body;
  throw new Error('Unsupported request body type.');
}

function normalizeRole(role) {
  return String(role || '').trim().toLowerCase();
}

function normalizeStatus(status) {
  return String(status || '').trim().toLowerCase();
}

function asNumber(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

function buildStableUserId(emailLower) {
  const digest = crypto.createHash('sha256').update(emailLower).digest('hex');
  return `user_${digest.slice(0, 32)}`;
}

function isMissingEmailIndex(error) {
  const message = (error?.message || '').toLowerCase();
  return message.includes('does not have the specified index');
}

function mapStatusToCookStatus(status) {
  switch (status) {
    case 'active':
      return 'approved';
    case 'frozen':
      return 'frozen';
    case 'warning':
      return 'pending_verification';
    case 'suspended':
      return 'blocked';
    default:
      return 'approved';
  }
}

function mapStatusToAccountStatus(status) {
  if (!status) return 'active';
  return status;
}

function isSupportedRole(role) {
  return (
    role === 'customer' ||
    role === 'cook' ||
    role === 'driver' ||
    role === 'admin'
  );
}

async function findUsersByEmail(emailLower) {
  const users = [];
  const seenKeys = new Set();
  const pushUnique = (items) => {
    for (const item of items) {
      const id = item?.id?.S || '';
      const email = item?.email?.S || '';
      const key = id || email;
      if (!key || seenKeys.has(key)) continue;
      seenKeys.add(key);
      users.push(item);
    }
  };

  let reachedAnyTable = false;
  for (const tableName of FALLBACK_TABLES) {
    if (!tableName) continue;
    try {
      reachedAnyTable = true;
      const result = await ddb.send(
        new QueryCommand({
          TableName: tableName,
          IndexName: 'email-index',
          KeyConditionExpression: 'email = :email',
          ExpressionAttributeValues: {
            ':email': { S: emailLower },
          },
        }),
      );
      const queryItems = result.Items ?? [];
      pushUnique(queryItems);

      const scan = await ddb.send(
        new ScanCommand({
          TableName: tableName,
          FilterExpression: 'email = :email',
          ExpressionAttributeValues: {
            ':email': { S: emailLower },
          },
          ConsistentRead: true,
          Limit: 25,
        }),
      );
      const scanItems = scan.Items ?? [];
      pushUnique(scanItems);
    } catch (error) {
      const code = String(error?.name || '').toLowerCase();
      if (code.includes('resourcenotfound')) {
        continue;
      }
      if (isMissingEmailIndex(error)) {
        const scan = await ddb.send(
          new ScanCommand({
            TableName: tableName,
            FilterExpression: 'email = :email',
            ExpressionAttributeValues: {
              ':email': { S: emailLower },
            },
            ConsistentRead: true,
            Limit: 25,
          }),
        );
        const scanItems = scan.Items ?? [];
        pushUnique(scanItems);
        continue;
      }
      throw error;
    }
  }

  if (!reachedAnyTable) {
    throw new Error('Unable to query any users table.');
  }
  return users;
}

async function putUser(item, { enforceUniqueId = false } = {}) {
  let lastError = null;
  for (const tableName of FALLBACK_TABLES) {
    if (!tableName) continue;
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
      const code = String(error?.name || '').toLowerCase();
      if (code.includes('resourcenotfound')) {
        lastError = error;
        continue;
      }
      throw error;
    }
  }

  if (lastError) throw lastError;
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
    const name = String(body.name || '').trim();
    const email = String(body.email || '').trim().toLowerCase();
    const phone = String(body.phone || '').trim();
    const role = normalizeRole(body.role);
    const status = normalizeStatus(body.status || 'active') || 'active';
    const rating = asNumber(body.rating, 0);
	    const totalOrders = Math.max(0, Math.round(asNumber(body.totalOrders, 0)));
	    const currentMonthOrders = Math.max(
	      0,
	      Math.round(asNumber(body.currentMonthOrders, 0)),
	    );
	    const followersCount = Math.max(0, Math.round(asNumber(body.followersCount, 0)));
	    const reelLikesCount = Math.max(0, Math.round(asNumber(body.reelLikesCount, 0)));
	    const ordersPlacedCount = Math.max(
	      0,
	      Math.round(asNumber(body.ordersPlacedCount, 0)),
	    );
	    const likedReelsCount = Math.max(0, Math.round(asNumber(body.likedReelsCount, 0)));
	    const followingCooksCount = Math.max(
	      0,
	      Math.round(asNumber(body.followingCooksCount, 0)),
	    );
    const complaintsCount = Math.max(
      0,
      Math.round(asNumber(body.complaintsCount, 0)),
    );
    const providedPassword = String(body.password || '').trim();
    const password = providedPassword || DEFAULT_TEMP_PASSWORD;

    if (!name || !email || !phone || !role) {
      return response(400, {
        message: 'Missing required fields: name, email, phone, role.',
      });
    }
    if (!isSupportedRole(role)) {
      return response(400, {
        message: 'Invalid role. Allowed: customer, cook, driver, admin.',
      });
    }
    if (!email.includes('@')) {
      return response(400, { message: 'Invalid email.' });
    }
    if (!password) {
      return response(400, {
        message:
          'Password is required. Provide password in request or set ADMIN_DEFAULT_USER_PASSWORD.',
      });
    }
    if (password.length < 6) {
      return response(400, {
        message: 'Password must be at least 6 characters.',
      });
    }

    const existing = await findUsersByEmail(email);
    if (existing.length > 0) {
      return response(409, { message: 'Email already exists.' });
    }

    const userId = buildStableUserId(email);
    const now = new Date().toISOString();
    const item = {
      id: { S: userId },
      name: { S: name },
      email: { S: email },
      phone: { S: phone },
      role: { S: role },
      accountStatus: { S: mapStatusToAccountStatus(status) },
	      rating: { N: String(rating) },
	      totalOrders: { N: String(totalOrders) },
	      currentMonthOrders: { N: String(currentMonthOrders) },
	      followersCount: { N: String(followersCount) },
	      reelLikesCount: { N: String(reelLikesCount) },
	      ordersPlacedCount: { N: String(ordersPlacedCount) },
	      likedReelsCount: { N: String(likedReelsCount) },
	      followingCooksCount: { N: String(followingCooksCount) },
	      complaintsCount: { N: String(complaintsCount) },
      createdAt: { S: now },
      authProvider: { S: 'admin' },
    };
    if (role === 'cook') {
      item.cookStatus = { S: mapStatusToCookStatus(status) };
    }
    if (password) {
      item.passwordHash = { S: hashPassword(password) };
    }

    const inserted = await putUser(item, { enforceUniqueId: true });
    if (!inserted) {
      return response(409, { message: 'Email already exists.' });
    }

    return response(200, {
      user: {
        id: userId,
        name,
        email,
        phone,
        role,
        createdAt: now,
        accountStatus: mapStatusToAccountStatus(status),
        cookStatus: role === 'cook' ? mapStatusToCookStatus(status) : '',
        status: mapStatusToAccountStatus(status),
	        rating,
	        totalOrders,
	        currentMonthOrders,
	        followersCount,
	        reelLikesCount,
	        ordersPlacedCount,
	        likedReelsCount,
	        followingCooksCount,
	        complaintsCount,
      },
      temporaryPassword:
        providedPassword.isEmpty && DEFAULT_TEMP_PASSWORD.isNotEmpty
          ? DEFAULT_TEMP_PASSWORD
          : null,
    });
  } catch (error) {
    console.error('usersSave error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
