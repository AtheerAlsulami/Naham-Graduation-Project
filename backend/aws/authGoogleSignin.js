const {
  DynamoDBClient,
  QueryCommand,
  PutItemCommand,
  UpdateItemCommand,
  ScanCommand,
} = require('@aws-sdk/client-dynamodb');
const https = require('https');
const crypto = require('crypto');

const ddb = new DynamoDBClient({});
const USERS_TABLE = process.env.USERS_TABLE;
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const FALLBACK_TABLES = ['users', 'naham_users'];
const GOOGLE_INTENT_LOGIN = 'login';
const GOOGLE_INTENT_REGISTER = 'register';
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

function normalizeIntent(value) {
  const intent = (value || '').toString().trim().toLowerCase();
  if (
    intent === GOOGLE_INTENT_LOGIN ||
    intent === GOOGLE_INTENT_REGISTER
  ) {
    return intent;
  }
  return null;
}

function buildStableUserId(emailLower) {
  const digest = crypto.createHash('sha256').update(emailLower).digest('hex');
  return `user_${digest.slice(0, 32)}`;
}

function sortUsersNewestFirst(items) {
  return [...items].sort((a, b) => {
    const left = a?.createdAt?.S || '';
    const right = b?.createdAt?.S || '';
    return right.localeCompare(left);
  });
}

function pickBestGoogleUser(items) {
  const sorted = sortUsersNewestFirst(items);
  const preferred = sorted.find((item) =>
    (item.authProvider?.S || '').toLowerCase() === 'google',
  );
  return preferred ?? sorted[0];
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
        return {
          users: items,
          tableName,
        };
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
        return {
          users: scannedItems,
          tableName,
        };
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
          return {
            users: items,
            tableName,
          };
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

  return null;
}

async function putUserWithFallbacks(item, {enforceUniqueId = false} = {}) {
  const tableNames = Array.from(
    new Set([USERS_TABLE, ...FALLBACK_TABLES].filter(Boolean)),
  );

  let lastError = null;
  for (const tableName of tableNames) {
    try {
      const params = {
        TableName: tableName,
        Item: item,
      };
      if (enforceUniqueId) {
        params.ConditionExpression = 'attribute_not_exists(id)';
      }
      await ddb.send(new PutItemCommand(params));
      return {
        inserted: true,
        tableName,
      };
    } catch (error) {
      if (
        enforceUniqueId &&
        error?.name === 'ConditionalCheckFailedException'
      ) {
        return {
          inserted: false,
          tableName,
        };
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

async function verifyGoogleIdToken(idToken) {
  const tokenInfoUrl = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(
    idToken,
  )}`;

  return new Promise((resolve, reject) => {
    const request = https.get(tokenInfoUrl, (res) => {
      let rawBody = '';
      res.on('data', (chunk) => {
        rawBody += chunk;
      });

      res.on('end', () => {
        const statusCode = res.statusCode || 0;
        if (statusCode < 200 || statusCode >= 300) {
          resolve({ ok: false, payload: null });
          return;
        }

        try {
          resolve({ ok: true, payload: JSON.parse(rawBody || '{}') });
        } catch (error) {
          reject(
            new Error(
              `Invalid Google token verification response: ${
                error.message || 'Unknown parse error'
              }`,
            ),
          );
        }
      });
    });

    request.on('error', (error) => {
      reject(
        new Error(
          `Google token verification request failed: ${
            error.message || 'Unknown request error'
          }`,
        ),
      );
    });

    request.setTimeout(10000, () => {
      request.destroy(new Error('Google token verification timed out.'));
    });
  });
}

async function verifyGoogleAccessToken(accessToken) {
  const tokenInfoUrl = `https://oauth2.googleapis.com/tokeninfo?access_token=${encodeURIComponent(
    accessToken,
  )}`;

  return new Promise((resolve, reject) => {
    const request = https.get(tokenInfoUrl, (res) => {
      let rawBody = '';
      res.on('data', (chunk) => {
        rawBody += chunk;
      });

      res.on('end', () => {
        const statusCode = res.statusCode || 0;
        if (statusCode < 200 || statusCode >= 300) {
          resolve({ ok: false, payload: null });
          return;
        }

        try {
          resolve({ ok: true, payload: JSON.parse(rawBody || '{}') });
        } catch (error) {
          reject(
            new Error(
              `Invalid Google access token verification response: ${
                error.message || 'Unknown parse error'
              }`,
            ),
          );
        }
      });
    });

    request.on('error', (error) => {
      reject(
        new Error(
          `Google access token verification request failed: ${
            error.message || 'Unknown request error'
          }`,
        ),
      );
    });

    request.setTimeout(10000, () => {
      request.destroy(
        new Error('Google access token verification timed out.'),
      );
    });
  });
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

function toUserPayload(user, fallback) {
  const accountStatus = pickString(user, 'accountStatus') || pickString(user, 'status');
  return {
    id: pickString(user, 'id'),
    name: fallback.name || pickString(user, 'name'),
    displayName: pickString(user, 'displayName'),
    email: fallback.email || pickString(user, 'email'),
    phone: pickString(user, 'phone'),
    role: pickString(user, 'role', fallback.role || 'customer'),
    profileImageUrl: fallback.picture || pickString(user, 'profileImageUrl'),
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

exports.handler = async (event) => {
  if (event?.requestContext?.http?.method === 'OPTIONS') {
    return response(200, { ok: true });
  }

  if (!USERS_TABLE) {
    return response(500, {
      message: 'Server misconfiguration: USERS_TABLE is not set.',
    });
  }
  if (!GOOGLE_CLIENT_ID) {
    return response(500, {
      message: 'Server misconfiguration: GOOGLE_CLIENT_ID is not set.',
    });
  }

  try {
    const body = parseBody(event);
    const idToken = (body.idToken || '').toString().trim();
    const accessToken = (body.accessToken || '').toString().trim();
    const role = (body.role || '').toString().trim().toLowerCase();
    const intent = normalizeIntent(body.intent);
    if (intent == null) {
      return response(400, { message: 'Missing intent.' });
    }
    if (!idToken && !accessToken) {
      return response(400, {
        message:
          'Missing Google token. Provide idToken or accessToken.',
      });
    }
    if (intent === GOOGLE_INTENT_REGISTER && !role) {
      return response(400, { message: 'Missing role for Google registration.' });
    }

    const verifyResult = idToken
      ? await verifyGoogleIdToken(idToken)
      : await verifyGoogleAccessToken(accessToken);
    if (!verifyResult.ok) {
      return response(401, { message: 'Invalid Google token.' });
    }

    const payload = verifyResult.payload;
    const audience = (payload.aud || payload.audience || '').toString().trim();
    const presenter = (payload.azp || payload.issued_to || '').toString().trim();
    const audienceMatches =
      audience === GOOGLE_CLIENT_ID || presenter === GOOGLE_CLIENT_ID;
    if (!audienceMatches) {
      return response(401, { message: 'Google token does not match client.' });
    }

    const email = (payload.email || '').toString().toLowerCase().trim();
    const name = (payload.name || '').toString().trim() || email.split('@')[0];
    const picture = (payload.picture || '').toString().trim();

    if (!email) {
      return response(401, { message: 'Google account email is missing.' });
    }

    const existing = await findUsersByEmail(email);

    let user;
    if (intent === GOOGLE_INTENT_LOGIN) {
      if (existing == null) {
        return response(404, {
          message:
            'No account found for this Google email. Create a new account first.',
        });
      }

      user = pickBestGoogleUser(existing.users);
      await ddb.send(
        new UpdateItemCommand({
          TableName: existing.tableName,
          Key: { id: { S: user.id.S } },
          UpdateExpression:
            'SET #name = :name, profileImageUrl = :picture, updatedAt = :updatedAt',
          ExpressionAttributeNames: {
            '#name': 'name',
          },
          ExpressionAttributeValues: {
            ':name': { S: name },
            ':picture': { S: picture },
            ':updatedAt': { S: new Date().toISOString() },
          },
        }),
      );
    } else if (existing != null) {
      const existingUser = pickBestGoogleUser(existing.users);
      if (existingUser.passwordHash?.S) {
        return response(409, {
          message:
            'This email is already registered with password. Use email login.',
        });
      }

      return response(409, {
        message:
          'This Google account is already registered. Use Continue with Google on login.',
      });
    } else {
      const userId = buildStableUserId(email);
      const now = new Date().toISOString();
      const newUserItem = {
        id: { S: userId },
        name: { S: name },
        email: { S: email },
        role: { S: role },
        phone: { S: '' },
        profileImageUrl: { S: picture },
        createdAt: { S: now },
        authProvider: { S: 'google' },
      };
      const inserted = await putUserWithFallbacks(newUserItem, {
        enforceUniqueId: true,
      });
      if (!inserted.inserted) {
        return response(409, {
          message:
            'This Google account is already registered. Use Continue with Google on login.',
        });
      }
      user = {
        id: { S: userId },
        name: { S: name },
        email: { S: email },
        role: { S: role },
        phone: { S: '' },
        profileImageUrl: { S: picture },
        createdAt: { S: now },
      };
    }

    const userPayload = toUserPayload(user, {
      name,
      email,
      role,
      picture,
    });

    return response(200, {
      user: userPayload,
      accessToken: userPayload.id,
      refreshToken: userPayload.id,
    });
  } catch (error) {
    console.error('authGoogleSignin error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
