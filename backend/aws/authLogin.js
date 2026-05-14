const { DynamoDBClient, QueryCommand, ScanCommand } = require('@aws-sdk/client-dynamodb');
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

function sortUsersNewestFirst(items) {
  return [...items].sort((a, b) => {
    const left = userRecordTimestamp(a);
    const right = userRecordTimestamp(b);
    return right.localeCompare(left);
  });
}

function sortUsersOldestFirst(items) {
  return [...items].sort((a, b) => {
    const left = userRecordTimestamp(a);
    const right = userRecordTimestamp(b);
    return left.localeCompare(right);
  });
}

function userRecordTimestamp(item) {
  return item?.updatedAt?.S || item?.createdAt?.S || '';
}

function hasStringAttr(item, key) {
  return typeof item?.[key]?.S === 'string' && item[key].S.trim() !== '';
}

function sameUserRecord(left, right, fallbackEmail) {
  const leftId = pickString(left, 'id');
  const rightId = pickString(right, 'id');
  if (leftId && rightId && leftId === rightId) return true;

  const leftEmail = pickString(left, 'email', fallbackEmail).toLowerCase();
  const rightEmail = pickString(right, 'email', fallbackEmail).toLowerCase();
  return Boolean(leftEmail && rightEmail && leftEmail === rightEmail);
}

function mergeUserRecords(primary, candidates) {
  const merged = { ...primary };
  for (const candidate of sortUsersOldestFirst(candidates)) {
    for (const [key, value] of Object.entries(candidate || {})) {
      if (key === 'passwordHash') {
        if (!hasStringAttr(merged, 'passwordHash') && hasStringAttr(candidate, key)) {
          merged[key] = value;
        }
        continue;
      }
      if (hasStringAttr(candidate, key) || !hasStringAttr(merged, key)) {
        merged[key] = value;
      }
    }
  }
  merged.passwordHash = primary.passwordHash;
  return merged;
}

function pickString(item, key, fallback = '') {
  return typeof item?.[key]?.S === 'string' ? item[key].S : fallback;
}

function pickNumber(item, key, fallback = 0) {
  if (typeof item?.[key]?.N !== 'string') return fallback;
  const parsed = Number(item[key].N);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function pickBool(item, key, fallback = null) {
  if (typeof item?.[key]?.BOOL === 'boolean') return item[key].BOOL;
  if (typeof item?.[key]?.N === 'string') {
    if (item[key].N === '1') return true;
    if (item[key].N === '0') return false;
  }
  if (typeof item?.[key]?.S === 'string') {
    const normalized = item[key].S.trim().toLowerCase();
    if (normalized === 'true' || normalized === '1') return true;
    if (normalized === 'false' || normalized === '0') return false;
  }
  return fallback;
}

function pickWorkingHours(item) {
  const raw = pickString(item, 'workingHours');
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? parsed
      : null;
  } catch (_) {
    return null;
  }
}

function toUserPayload(user, fallbackEmail) {
  const accountStatus = pickString(user, 'accountStatus') || pickString(user, 'status');
  return {
    id: pickString(user, 'id'),
    name: pickString(user, 'name'),
    displayName: pickString(user, 'displayName'),
    email: pickString(user, 'email', fallbackEmail),
    phone: pickString(user, 'phone'),
    role: pickString(user, 'role', 'customer'),
    profileImageUrl: pickString(user, 'profileImageUrl'),
    address: pickString(user, 'address'),
    createdAt: pickString(user, 'createdAt', new Date().toISOString()),
    updatedAt: pickString(user, 'updatedAt'),
    status: accountStatus || 'active',
    accountStatus: accountStatus || 'active',
    cookStatus: pickString(user, 'cookStatus'),
    rating: pickNumber(user, 'rating', 0),
    totalOrders: Math.round(pickNumber(user, 'totalOrders', 0)),
    currentMonthOrders: Math.round(pickNumber(user, 'currentMonthOrders', 0)),
    followersCount: Math.round(pickNumber(user, 'followersCount', 0)),
    reelLikesCount: Math.round(pickNumber(user, 'reelLikesCount', 0)),
    ordersPlacedCount: Math.round(pickNumber(user, 'ordersPlacedCount', 0)),
    likedReelsCount: Math.round(pickNumber(user, 'likedReelsCount', 0)),
    followingCooksCount: Math.round(pickNumber(user, 'followingCooksCount', 0)),
    isOnline: pickBool(user, 'isOnline'),
    dailyCapacity:
      typeof user?.dailyCapacity?.N === 'string'
        ? Math.round(pickNumber(user, 'dailyCapacity', 0))
        : null,
    workingHours: pickWorkingHours(user),
    specialty: pickString(user, 'specialty'),
    priceRange: pickString(user, 'priceRange'),
    deliveryTime: pickString(user, 'deliveryTime'),
    verificationIdUrl: pickString(user, 'verificationIdUrl'),
    verificationHealthUrl: pickString(user, 'verificationHealthUrl'),
  };
}

async function findUsersByEmail(email) {
  const tableNames = Array.from(
    new Set([USERS_TABLE, ...FALLBACK_TABLES].filter(Boolean)),
  );

  const users = [];
  const pushItems = (items) => {
    for (const item of items) {
      users.push(item);
    }
  };

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
      const queryItems = result.Items ?? [];
      pushItems(queryItems);
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
      pushItems(scannedItems);
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
        pushItems(items);
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
  return users;
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
    const email = (body.email || '').toString().trim();
    const password = (body.password || '').toString();

    if (!email || !password) {
      return response(400, { message: 'Missing required fields.' });
    }

    const emailLower = email.toLowerCase();
    const items = sortUsersNewestFirst(await findUsersByEmail(emailLower));
    if (items.length === 0) {
      return response(404, {
        message: 'No account found for this email. Create a new account first.',
      });
    }

    const attemptHash = hashPassword(password);
    const usersWithPassword = items.filter(
      (item) => typeof item.passwordHash?.S === 'string' && item.passwordHash.S,
    );

    if (usersWithPassword.length === 0) {
      return response(401, {
        message:
          'This account was created with Google Sign-In. Use Continue with Google.',
      });
    }

    const matchedUser = usersWithPassword.find(
      (item) => item.passwordHash?.S === attemptHash,
    );
    if (!matchedUser) {
      return response(401, { message: 'Invalid credentials.' });
    }

    const user = mergeUserRecords(
      matchedUser,
      items.filter((item) => sameUserRecord(matchedUser, item, emailLower)),
    );
    const userPayload = toUserPayload(user, emailLower);
    return response(200, {
      user: userPayload,
      accessToken: userPayload.id,
      refreshToken: userPayload.id,
    });
  } catch (error) {
    console.error('authLogin error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
