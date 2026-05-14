const {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
} = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});
const CONVERSATIONS_TABLE =
  process.env.CONVERSATIONS_TABLE || process.env.CHAT_TABLE || 'conversations';
const FALLBACK_TABLES = parseCsv(
  process.env.CONVERSATIONS_FALLBACK_TABLES || process.env.CHAT_FALLBACK_TABLES,
);

const SUPPORT_PARTICIPANT_ID = '__support__';
const AWS_REGION =
  process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'unknown';

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

function asString(value, fallback = '') {
  if (value == null) return fallback;
  return String(value).trim();
}

function isUsableTableName(value) {
  const normalized = asString(value).toLowerCase();
  return (
    normalized !== '' &&
    normalized !== 'undefined' &&
    normalized !== 'null' &&
    normalized !== 'none' &&
    normalized !== 'n/a' &&
    normalized !== 'na'
  );
}

function parseCsv(value) {
  return String(value || '')
    .split(',')
    .map((table) => table.trim())
    .filter(isUsableTableName);
}

function requestMethod(event) {
  return asString(event?.requestContext?.http?.method || event?.httpMethod)
    .toUpperCase();
}

function asNumber(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function nowIso() {
  return new Date().toISOString();
}

function isAdminRole(role) {
  return asString(role).toLowerCase() === 'admin';
}

function isResourceNotFound(error) {
  const code = String(error?.name || '').toLowerCase();
  return code.includes('resourcenotfound');
}

function tableNames() {
  return Array.from(
    new Set([CONVERSATIONS_TABLE, ...FALLBACK_TABLES, 'conversations'].filter(isUsableTableName)),
  );
}

function conversationStorageId(conversationId) {
  return `conv_${conversationId}`;
}

function pickString(attrValue, fallback = '') {
  return typeof attrValue?.S === 'string' ? attrValue.S : fallback;
}

function pickBool(attrValue, fallback = false) {
  return typeof attrValue?.BOOL === 'boolean' ? attrValue.BOOL : fallback;
}

function pickStringList(attrValue) {
  if (!Array.isArray(attrValue?.L)) return [];
  return attrValue.L
    .map((item) => (typeof item?.S === 'string' ? item.S.trim() : ''))
    .filter(Boolean);
}

function pickStringMap(attrValue) {
  if (!attrValue?.M || typeof attrValue.M !== 'object') {
    return {};
  }
  const result = {};
  for (const [key, value] of Object.entries(attrValue.M)) {
    result[key] = pickString(value);
  }
  return result;
}

function pickNumberMap(attrValue) {
  if (!attrValue?.M || typeof attrValue.M !== 'object') {
    return {};
  }
  const result = {};
  for (const [key, value] of Object.entries(attrValue.M)) {
    const parsed = Number(value?.N);
    result[key] = Number.isFinite(parsed) ? parsed : 0;
  }
  return result;
}

function mapItemToConversation(item) {
  return {
    conversationId: pickString(item.conversationId),
    isSupport: pickBool(item.isSupport, false),
    participantIds: pickStringList(item.participantIds),
    participantRoles: pickStringMap(item.participantRoles),
    participantNames: pickStringMap(item.participantNames),
    participantAvatars: pickStringMap(item.participantAvatars),
    phoneNumbers: pickStringMap(item.phoneNumbers),
    unreadByUser: pickNumberMap(item.unreadByUser),
    lastMessage: pickString(item.lastMessage),
    lastMessageAt: pickString(item.lastMessageAt, nowIso()),
    hasPriorityBorder: pickBool(item.hasPriorityBorder, false),
    isComplaint: pickBool(item.isComplaint, false),
    createdAt: pickString(item.createdAt, nowIso()),
  };
}

function listToAttr(values) {
  return {
    L: values.map((value) => ({ S: asString(value) })),
  };
}

function mapToStringAttr(map) {
  const mapped = {};
  for (const [key, value] of Object.entries(map || {})) {
    mapped[asString(key)] = { S: asString(value) };
  }
  return { M: mapped };
}

function mapToNumberAttr(map) {
  const mapped = {};
  for (const [key, value] of Object.entries(map || {})) {
    mapped[asString(key)] = { N: String(asNumber(value, 0)) };
  }
  return { M: mapped };
}

function mapToConversationItem(conversation) {
  return {
    id: { S: conversationStorageId(conversation.conversationId) },
    itemType: { S: 'conversation' },
    conversationId: { S: asString(conversation.conversationId) },
    isSupport: { BOOL: !!conversation.isSupport },
    participantIds: listToAttr(conversation.participantIds || []),
    participantRoles: mapToStringAttr(conversation.participantRoles || {}),
    participantNames: mapToStringAttr(conversation.participantNames || {}),
    participantAvatars: mapToStringAttr(conversation.participantAvatars || {}),
    phoneNumbers: mapToStringAttr(conversation.phoneNumbers || {}),
    unreadByUser: mapToNumberAttr(conversation.unreadByUser || {}),
    lastMessage: { S: asString(conversation.lastMessage) },
    lastMessageAt: { S: asString(conversation.lastMessageAt || nowIso()) },
    hasPriorityBorder: { BOOL: !!conversation.hasPriorityBorder },
    isComplaint: { BOOL: !!conversation.isComplaint },
    createdAt: { S: asString(conversation.createdAt || nowIso()) },
  };
}

function canAccessConversation(conversation, userId, role) {
  if (isAdminRole(role)) {
    return conversation.isSupport;
  }
  return Array.isArray(conversation.participantIds)
    ? conversation.participantIds.includes(userId)
    : false;
}

async function getConversation(conversationId) {
  const names = tableNames();
  const storageId = conversationStorageId(conversationId);
  let lastError = null;
  let hasTable = false;

  for (const tableName of names) {
    try {
      hasTable = true;
      const result = await ddb.send(
        new GetItemCommand({
          TableName: tableName,
          Key: {
            id: { S: storageId },
          },
        }),
      );
      if (!result.Item) {
        continue;
      }
      return mapItemToConversation(result.Item);
    } catch (error) {
      if (isResourceNotFound(error)) {
        lastError = error;
        continue;
      }
      throw error;
    }
  }

  if (lastError) throw lastError;
  if (hasTable) {
    return null;
  }
  throw new Error('No chat table is available.');
}

async function putConversation(conversation) {
  const names = tableNames();
  const item = mapToConversationItem(conversation);
  let lastError = null;

  for (const tableName of names) {
    try {
      await ddb.send(
        new PutItemCommand({
          TableName: tableName,
          Item: item,
        }),
      );
      return;
    } catch (error) {
      if (isResourceNotFound(error)) {
        lastError = error;
        continue;
      }
      throw error;
    }
  }

  if (lastError) throw lastError;
  throw new Error('No writable chat table is available.');
}

exports.handler = async (event) => {
  const method = requestMethod(event);
  if (method === 'OPTIONS') {
    return response(200, { ok: true });
  }

  try {
    console.info('chatMarkRead invoke', {
      method,
      region: AWS_REGION,
      conversationsTable: CONVERSATIONS_TABLE,
      fallbackTables: FALLBACK_TABLES,
    });
    if (method !== 'POST') {
      return response(405, { message: 'Method not allowed.' });
    }

    const conversationId = asString(
      event?.pathParameters?.conversationId || event?.pathParameters?.id,
    );
    if (!conversationId) {
      return response(400, { message: 'Missing conversationId in path.' });
    }

    const body = parseBody(event);
    const userId = asString(body.userId);
    const userRole = asString(body.userRole || body.role);
    if (!userId) {
      return response(400, { message: 'Missing required field: userId.' });
    }

    const conversation = await getConversation(conversationId);
    if (!conversation) {
      return response(404, { message: 'Conversation not found.' });
    }
    if (!canAccessConversation(conversation, userId, userRole)) {
      return response(403, { message: 'Access denied for this conversation.' });
    }

    const unreadByUser = { ...(conversation.unreadByUser || {}) };
    const unreadKey =
      isAdminRole(userRole) && conversation.isSupport
        ? SUPPORT_PARTICIPANT_ID
        : userId;
    unreadByUser[unreadKey] = 0;

    const updatedConversation = {
      ...conversation,
      unreadByUser,
    };
    await putConversation(updatedConversation);

    return response(200, {
      conversation: updatedConversation,
    });
  } catch (error) {
    console.error('chatMarkRead error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
