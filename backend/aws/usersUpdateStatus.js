const { DynamoDBClient, UpdateItemCommand } = require('@aws-sdk/client-dynamodb');

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

const JSON_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'OPTIONS,PUT',
};

const ALLOWED_ACCOUNT_STATUSES = new Set([
  'active',
  'warning',
  'frozen',
  'suspended',
]);

const ALLOWED_COOK_STATUSES = new Set([
  'approved',
  'pending_verification',
  'frozen',
  'blocked',
  'rejected',
]);

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

function normalize(value) {
  return String(value || '').trim().toLowerCase();
}

function hasOwn(source, key) {
  return Object.prototype.hasOwnProperty.call(source, key);
}

function pickString(attrValue, fallback = '') {
  return typeof attrValue?.S === 'string' ? attrValue.S : fallback;
}

function pickNumber(attrValue, fallback = 0) {
  if (typeof attrValue?.N !== 'string') return fallback;
  const parsed = Number(attrValue.N);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function pickBool(attrValue, fallback = null) {
  if (typeof attrValue?.BOOL === 'boolean') return attrValue.BOOL;
  if (typeof attrValue?.N === 'string') {
    if (attrValue.N === '1') return true;
    if (attrValue.N === '0') return false;
  }
  if (typeof attrValue?.S === 'string') {
    const value = normalize(attrValue.S);
    if (value === 'true' || value === '1') return true;
    if (value === 'false' || value === '0') return false;
  }
  return fallback;
}

function pickWorkingHours(attrValue) {
  if (typeof attrValue?.S !== 'string') {
    return null;
  }
  const raw = attrValue.S.trim();
  if (!raw) {
    return null;
  }
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed;
    }
    return null;
  } catch (_) {
    return null;
  }
}

function buildDocuments(attrs) {
  const documents = [];
  const idUrl = pickString(attrs.verificationIdUrl);
  const healthUrl = pickString(attrs.verificationHealthUrl);

  if (idUrl) {
    documents.push({
      title: 'Identity document',
      type: 'id',
      url: idUrl,
    });
  }
  if (healthUrl) {
    documents.push({
      title: 'Health certificate',
      type: 'health',
      url: healthUrl,
    });
  }

  return documents;
}

function mapUser(attrs) {
  const cookStatus = pickString(attrs.cookStatus);
  const accountStatus = pickString(attrs.accountStatus) || pickString(attrs.status);
  const verificationIdUrl = pickString(attrs.verificationIdUrl);
  const verificationHealthUrl = pickString(attrs.verificationHealthUrl);

  return {
    id: pickString(attrs.id),
    name: pickString(attrs.name),
    displayName: pickString(attrs.displayName),
    email: pickString(attrs.email),
    phone: pickString(attrs.phone),
    role: pickString(attrs.role, 'customer'),
    profileImageUrl: pickString(attrs.profileImageUrl),
    address: pickString(attrs.address),
    createdAt: pickString(attrs.createdAt, new Date().toISOString()),
    updatedAt: pickString(attrs.updatedAt),
    status: accountStatus || 'active',
    accountStatus: accountStatus || 'active',
	    cookStatus,
	    rating: pickNumber(attrs.rating, 0),
	    totalOrders: Math.round(pickNumber(attrs.totalOrders, 0)),
	    currentMonthOrders: Math.round(pickNumber(attrs.currentMonthOrders, 0)),
	    followersCount: Math.round(pickNumber(attrs.followersCount, 0)),
	    reelLikesCount: Math.round(pickNumber(attrs.reelLikesCount, 0)),
	    ordersPlacedCount: Math.round(pickNumber(attrs.ordersPlacedCount, 0)),
	    likedReelsCount: Math.round(pickNumber(attrs.likedReelsCount, 0)),
	    followingCooksCount: Math.round(pickNumber(attrs.followingCooksCount, 0)),
	    complaintsCount: Math.round(pickNumber(attrs.complaintsCount, 0)),
    isOnline: pickBool(attrs.isOnline),
    verificationIdUrl,
    verificationHealthUrl,
    documents: buildDocuments(attrs),
    dailyCapacity:
      typeof attrs.dailyCapacity?.N === 'string'
        ? Math.round(pickNumber(attrs.dailyCapacity, 0))
        : null,
    workingHours: pickWorkingHours(attrs.workingHours),
  };
}

function parseOptionalBool(value, fieldName) {
  if (value == null) return null;
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') {
    if (value === 1) return true;
    if (value === 0) return false;
  }
  if (typeof value === 'string') {
    const normalized = normalize(value);
    if (normalized === 'true' || normalized === '1') return true;
    if (normalized === 'false' || normalized === '0') return false;
  }
  throw new Error(`Invalid ${fieldName}. Expected boolean.`);
}

function parseOptionalInt(value, fieldName) {
  if (value == null || String(value).trim() === '') {
    return null;
  }
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new Error(`Invalid ${fieldName}. Expected a number.`);
  }
  const rounded = Math.round(parsed);
  if (rounded < 0) {
    throw new Error(`Invalid ${fieldName}. Must be 0 or greater.`);
  }
  return rounded;
}

function parseOptionalObjectAsJson(value, fieldName) {
  if (value == null) {
    return null;
  }
  if (typeof value === 'string') {
    const raw = value.trim();
    if (!raw) {
      return null;
    }
    try {
      const parsed = JSON.parse(raw);
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
        throw new Error(`Invalid ${fieldName}. Expected JSON object.`);
      }
      return JSON.stringify(parsed);
    } catch (_) {
      throw new Error(`Invalid ${fieldName}. Expected JSON object.`);
    }
  }
  if (typeof value === 'object' && !Array.isArray(value)) {
    return JSON.stringify(value);
  }
  throw new Error(`Invalid ${fieldName}. Expected object.`);
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
    const userId = String(event?.pathParameters?.id || '').trim();
    if (!userId) {
      return response(400, { message: 'Missing required path parameter: id.' });
    }

    const body = parseBody(event);
    const now = new Date().toISOString();

    const setParts = ['updatedAt = :updatedAt'];
    const removeParts = [];
    const expressionNames = {};
    const expressionValues = {
      ':updatedAt': { S: now },
    };

    const hasStatusField = hasOwn(body, 'status') || hasOwn(body, 'accountStatus');
    const status = hasStatusField ? normalize(body.status || body.accountStatus) : '';
    if (hasStatusField) {
      if (!status) {
        return response(400, { message: 'Status cannot be empty.' });
      }
      if (!ALLOWED_ACCOUNT_STATUSES.has(status)) {
        return response(400, {
          message: 'Invalid status. Allowed: active, warning, frozen, suspended.',
        });
      }

      expressionNames['#status'] = 'status';
      expressionValues[':status'] = { S: status };
      setParts.push('accountStatus = :status');
      setParts.push('#status = :status');
    }

    if (hasOwn(body, 'cookStatus')) {
      const cookStatus = normalize(body.cookStatus);
      if (cookStatus) {
        if (!ALLOWED_COOK_STATUSES.has(cookStatus)) {
          return response(400, {
            message:
              'Invalid cookStatus. Allowed: approved, pending_verification, frozen, blocked, rejected.',
          });
        }
        expressionValues[':cookStatus'] = { S: cookStatus };
        setParts.push('cookStatus = :cookStatus');
      } else {
        removeParts.push('cookStatus');
      }
    }

    if (hasOwn(body, 'name')) {
      const name = String(body.name || '').trim();
      if (!name) {
        return response(400, { message: 'Name cannot be empty.' });
      }
      expressionNames['#name'] = 'name';
      expressionValues[':name'] = { S: name };
      setParts.push('#name = :name');
    }

    if (hasOwn(body, 'phone')) {
      const phone = String(body.phone || '').trim();
      if (!phone) {
        return response(400, { message: 'Phone cannot be empty.' });
      }
      expressionValues[':phone'] = { S: phone };
      setParts.push('phone = :phone');
    }

    if (hasOwn(body, 'displayName')) {
      const displayName = String(body.displayName || '').trim();
      if (!displayName) {
        removeParts.push('displayName');
      } else {
        expressionValues[':displayName'] = { S: displayName };
        setParts.push('displayName = :displayName');
      }
    }

    if (hasOwn(body, 'address')) {
      const address = String(body.address || '').trim();
      if (!address) {
        removeParts.push('address');
      } else {
        expressionValues[':address'] = { S: address };
        setParts.push('address = :address');
      }
    }

    if (hasOwn(body, 'profileImageUrl')) {
      const profileImageUrl = String(body.profileImageUrl || '').trim();
      if (!profileImageUrl) {
        removeParts.push('profileImageUrl');
      } else {
        expressionValues[':profileImageUrl'] = { S: profileImageUrl };
        setParts.push('profileImageUrl = :profileImageUrl');
      }
    }

    if (hasOwn(body, 'verificationIdUrl')) {
      const verificationIdUrl = String(body.verificationIdUrl || '').trim();
      if (!verificationIdUrl) {
        removeParts.push('verificationIdUrl');
      } else {
        expressionValues[':verificationIdUrl'] = { S: verificationIdUrl };
        setParts.push('verificationIdUrl = :verificationIdUrl');
      }
    }

    if (hasOwn(body, 'verificationHealthUrl')) {
      const verificationHealthUrl = String(body.verificationHealthUrl || '').trim();
      if (!verificationHealthUrl) {
        removeParts.push('verificationHealthUrl');
      } else {
        expressionValues[':verificationHealthUrl'] = { S: verificationHealthUrl };
        setParts.push('verificationHealthUrl = :verificationHealthUrl');
      }
    }

    if (hasOwn(body, 'isOnline')) {
      const isOnline = parseOptionalBool(body.isOnline, 'isOnline');
      if (isOnline == null) {
        removeParts.push('isOnline');
      } else {
        expressionValues[':isOnline'] = { BOOL: isOnline };
        setParts.push('isOnline = :isOnline');
      }
    }

    if (hasOwn(body, 'dailyCapacity')) {
      const dailyCapacity = parseOptionalInt(body.dailyCapacity, 'dailyCapacity');
      if (dailyCapacity == null) {
        removeParts.push('dailyCapacity');
      } else {
        expressionValues[':dailyCapacity'] = { N: String(dailyCapacity) };
        setParts.push('dailyCapacity = :dailyCapacity');
      }
    }

    if (hasOwn(body, 'workingHours')) {
      const workingHours = parseOptionalObjectAsJson(
        body.workingHours,
        'workingHours',
      );
      if (workingHours == null) {
        removeParts.push('workingHours');
      } else {
        expressionValues[':workingHours'] = { S: workingHours };
        setParts.push('workingHours = :workingHours');
      }
    }

    if (setParts.length === 1 && removeParts.length === 0) {
      return response(400, {
        message:
          'No fields to update. Provide one of: status, cookStatus, name, phone, displayName, address, profileImageUrl, verificationIdUrl, verificationHealthUrl, isOnline, dailyCapacity, workingHours.',
      });
    }

    const updateExpression = [
      `SET ${setParts.join(', ')}`,
      removeParts.length > 0 ? `REMOVE ${removeParts.join(', ')}` : '',
    ]
      .filter(Boolean)
      .join(' ');

    let updatedCount = 0;
    let updatedUser = null;
    let lastError = null;
    let matchedAnyTable = false;

    for (const tableName of FALLBACK_TABLES) {
      if (!tableName) continue;
      try {
        const result = await ddb.send(
          new UpdateItemCommand({
            TableName: tableName,
            Key: { id: { S: userId } },
            ConditionExpression: 'attribute_exists(id)',
            UpdateExpression: updateExpression,
            ExpressionAttributeNames:
              Object.keys(expressionNames).length > 0 ? expressionNames : undefined,
            ExpressionAttributeValues: expressionValues,
            ReturnValues: 'ALL_NEW',
          }),
        );

        matchedAnyTable = true;
        if (result.Attributes) {
          updatedCount += 1;
          if (!updatedUser) {
            updatedUser = mapUser(result.Attributes);
          }
        }
      } catch (error) {
        const code = String(error?.name || '').toLowerCase();
        if (code.includes('resourcenotfound')) {
          lastError = error;
          continue;
        }
        if (error?.name === 'ConditionalCheckFailedException') {
          matchedAnyTable = true;
          continue;
        }
        if (code.includes('validationexception')) {
          if (updatedCount > 0) {
            continue;
          }
          lastError = error;
          continue;
        }
        throw error;
      }
    }

    if (updatedCount === 0) {
      if (!matchedAnyTable && lastError) {
        throw lastError;
      }
      return response(404, { message: 'User not found.', id: userId });
    }

    return response(200, {
      user: updatedUser ?? { id: userId },
      updated: true,
      updatedCount,
    });
  } catch (error) {
    console.error('usersUpdateStatus error:', error);
    const message = error?.message || '';
    if (
      message.startsWith('Invalid ') ||
      message.endsWith('cannot be empty.') ||
      message.includes('Must be 0 or greater.')
    ) {
      return response(400, { message });
    }
    return response(500, {
      message: 'Internal server error.',
      error: message || 'Unknown error',
    });
  }
};
