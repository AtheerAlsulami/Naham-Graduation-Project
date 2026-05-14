const {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
  ScanCommand,
} = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});
const CONVERSATIONS_TABLE =
  process.env.CONVERSATIONS_TABLE || process.env.CHAT_TABLE || 'conversations';
const FALLBACK_TABLES = parseCsv(
  process.env.CONVERSATIONS_FALLBACK_TABLES || process.env.CHAT_FALLBACK_TABLES,
);

const SUPPORT_PARTICIPANT_ID = '__support__';
const SUPPORT_NAME = process.env.SUPPORT_NAME || 'Naham Support';
const AWS_REGION =
  process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'unknown';

const JSON_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'OPTIONS,GET,POST',
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

function asBool(value, fallback = false) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true' || normalized === '1') return true;
    if (normalized === 'false' || normalized === '0') return false;
  }
  return fallback;
}

function nowIso() {
  return new Date().toISOString();
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

function conversationBusinessIdFromStorageId(storageId) {
  return storageId.replace(/^conv_/, '');
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
    const numberValue = Number(value);
    mapped[asString(key)] = {
      N: Number.isFinite(numberValue) ? String(numberValue) : '0',
    };
  }
  return { M: mapped };
}

function mapToConversationItem(conversation) {
  return {
    id: { S: conversationStorageId(conversation.conversationId) },
    itemType: { S: 'conversation' },
    conversationId: { S: asString(conversation.conversationId) },
    isSupport: { BOOL: asBool(conversation.isSupport, false) },
    participantIds: listToAttr(conversation.participantIds || []),
    participantRoles: mapToStringAttr(conversation.participantRoles || {}),
    participantNames: mapToStringAttr(conversation.participantNames || {}),
    participantAvatars: mapToStringAttr(conversation.participantAvatars || {}),
    phoneNumbers: mapToStringAttr(conversation.phoneNumbers || {}),
    unreadByUser: mapToNumberAttr(conversation.unreadByUser || {}),
    lastMessage: { S: asString(conversation.lastMessage) },
    lastMessageAt: { S: asString(conversation.lastMessageAt || nowIso()) },
    hasPriorityBorder: { BOOL: asBool(conversation.hasPriorityBorder, false) },
    isComplaint: { BOOL: asBool(conversation.isComplaint, false) },
    createdAt: { S: asString(conversation.createdAt || nowIso()) },
  };
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
  const storageId = pickString(item.id);
  return {
    conversationId: pickString(
      item.conversationId,
      conversationBusinessIdFromStorageId(storageId),
    ),
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

function buildSupportConversation({
  userId,
  userRole,
  userName,
  userAvatarUrl,
  userPhone,
}) {
  const conversationId = `support_${userId}`;
  const createdAt = nowIso();
  return {
    conversationId,
    isSupport: true,
    participantIds: [userId, SUPPORT_PARTICIPANT_ID],
    participantRoles: {
      [userId]: userRole || 'customer',
      [SUPPORT_PARTICIPANT_ID]: 'support',
    },
    participantNames: {
      [userId]: userName || userId,
      [SUPPORT_PARTICIPANT_ID]: SUPPORT_NAME,
    },
    participantAvatars: {
      [userId]: userAvatarUrl || '',
      [SUPPORT_PARTICIPANT_ID]: '',
    },
    phoneNumbers: {
      [userId]: userPhone || '',
      [SUPPORT_PARTICIPANT_ID]: '',
    },
    unreadByUser: {
      [userId]: 0,
      [SUPPORT_PARTICIPANT_ID]: 0,
    },
    lastMessage: '',
    lastMessageAt: createdAt,
    hasPriorityBorder: false,
    isComplaint: false,
    createdAt,
  };
}

function buildDirectConversation({
  userId,
  userRole,
  userName,
  userAvatarUrl,
  userPhone,
  otherUserId,
  otherUserRole,
  otherUserName,
  otherUserAvatarUrl,
  otherUserPhone,
}) {
  const a = asString(userId);
  const b = asString(otherUserId);
  const orderedIds = [a, b].sort();
  const conversationId = `dm_${orderedIds[0]}__${orderedIds[1]}`;
  const createdAt = nowIso();

  return {
    conversationId,
    isSupport: false,
    participantIds: [a, b],
    participantRoles: {
      [a]: userRole || 'customer',
      [b]: otherUserRole || 'cook',
    },
    participantNames: {
      [a]: userName || a,
      [b]: otherUserName || b,
    },
    participantAvatars: {
      [a]: userAvatarUrl || '',
      [b]: otherUserAvatarUrl || '',
    },
    phoneNumbers: {
      [a]: userPhone || '',
      [b]: otherUserPhone || '',
    },
    unreadByUser: {
      [a]: 0,
      [b]: 0,
    },
    lastMessage: '',
    lastMessageAt: createdAt,
    hasPriorityBorder: false,
    isComplaint: false,
    createdAt,
  };
}

async function loadAllChatItems() {
  const names = tableNames();
  let lastError = null;

  for (const tableName of names) {
    try {
      let lastEvaluatedKey;
      const allItems = [];
      do {
        const result = await ddb.send(
          new ScanCommand({
            TableName: tableName,
            ExclusiveStartKey: lastEvaluatedKey,
          }),
        );
        allItems.push(...(result.Items || []));
        lastEvaluatedKey = result.LastEvaluatedKey;
      } while (lastEvaluatedKey);

      return { items: allItems, tableName };
    } catch (error) {
      if (isResourceNotFound(error)) {
        lastError = error;
        continue;
      }
      throw error;
    }
  }

  if (lastError) {
    throw lastError;
  }
  throw new Error('No chat table is available.');
}

async function getConversation(conversationId) {
  const names = tableNames();
  const storageId = conversationStorageId(conversationId);
  let lastError = null;
  let resolvedTableName = names[0] || CONVERSATIONS_TABLE;

  for (const tableName of names) {
    try {
      resolvedTableName = tableName;
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
      return {
        conversation: mapItemToConversation(result.Item),
        tableName,
      };
    } catch (error) {
      if (isResourceNotFound(error)) {
        lastError = error;
        continue;
      }
      throw error;
    }
  }

  if (lastError) throw lastError;
  if (resolvedTableName) {
    return { conversation: null, tableName: resolvedTableName };
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

function sortByLastMessageDesc(conversations) {
  return [...conversations].sort((a, b) =>
    String(b.lastMessageAt || '').localeCompare(String(a.lastMessageAt || '')),
  );
}

function isAdminRole(role) {
  return asString(role).toLowerCase() === 'admin';
}

function filterConversationsForUser(conversations, userId, role) {
  if (isAdminRole(role)) {
    return conversations.filter((item) => item.isSupport);
  }
  return conversations.filter((item) =>
    Array.isArray(item.participantIds)
      ? item.participantIds.includes(userId)
      : false,
  );
}

async function ensureSupportConversationForUser({
  userId,
  userRole,
  userName,
  userAvatarUrl,
  userPhone,
}) {
  const conversationId = `support_${userId}`;
  const existing = await getConversation(conversationId);
  if (existing.conversation) {
    return existing.conversation;
  }

  const created = buildSupportConversation({
    userId,
    userRole,
    userName,
    userAvatarUrl,
    userPhone,
  });
  await putConversation(created);
  return created;
}

async function handleList(event) {
  const query = event?.queryStringParameters || {};
  const userId = asString(query.userId);
  const role = asString(query.role || query.userRole);
  const userName = asString(query.userName);
  const userAvatarUrl = asString(query.userAvatarUrl);
  const userPhone = asString(query.userPhone);

  if (!userId) {
    return response(400, {
      message: 'Missing userId query parameter.',
    });
  }

  const { items } = await loadAllChatItems();
  const conversations = items
    .filter((item) => pickString(item.itemType) === 'conversation')
    .map(mapItemToConversation);

  let filtered = filterConversationsForUser(conversations, userId, role);

  if (!isAdminRole(role)) {
    const hasSupportConversation = filtered.some(
      (item) => item.isSupport && item.participantIds.includes(userId),
    );
    if (!hasSupportConversation) {
      const supportConversation = await ensureSupportConversationForUser({
        userId,
        userRole: role,
        userName,
        userAvatarUrl,
        userPhone,
      });
      filtered = [...filtered, supportConversation];
    }
  }

  return response(200, {
    items: sortByLastMessageDesc(filtered),
    count: filtered.length,
  });
}

async function handleCreate(event) {
  const body = parseBody(event);
  const userId = asString(body.userId);
  const userRole = asString(body.userRole || body.role || 'customer');
  const userName = asString(body.userName, userId);
  const userAvatarUrl = asString(body.userAvatarUrl);
  const userPhone = asString(body.userPhone);
  const type = asString(body.type || 'support').toLowerCase();

  if (!userId) {
    return response(400, { message: 'Missing required field: userId.' });
  }

  let conversation;
  if (type === 'support') {
    conversation = buildSupportConversation({
      userId,
      userRole,
      userName,
      userAvatarUrl,
      userPhone,
    });
  } else {
    const otherUserId = asString(body.otherUserId);
    if (!otherUserId) {
      return response(400, {
        message: 'Missing required field: otherUserId.',
      });
    }
    conversation = buildDirectConversation({
      userId,
      userRole,
      userName,
      userAvatarUrl,
      userPhone,
      otherUserId,
      otherUserRole: asString(body.otherUserRole || type || 'cook'),
      otherUserName: asString(body.otherUserName, otherUserId),
      otherUserAvatarUrl: asString(body.otherUserAvatarUrl),
      otherUserPhone: asString(body.otherUserPhone),
    });
  }

  const existing = await getConversation(conversation.conversationId);
  if (existing.conversation) {
    return response(200, {
      conversation: existing.conversation,
      created: false,
    });
  }

  await putConversation(conversation);
  return response(200, {
    conversation,
    created: true,
  });
}

exports.handler = async (event) => {
  const method = requestMethod(event);
  if (method === 'OPTIONS') {
    return response(200, { ok: true });
  }

  try {
    console.info('chatConversations invoke', {
      method,
      region: AWS_REGION,
      conversationsTable: CONVERSATIONS_TABLE,
      fallbackTables: FALLBACK_TABLES,
    });
    if (method === 'GET') {
      return await handleList(event);
    }
    if (method === 'POST') {
      return await handleCreate(event);
    }
    return response(405, { message: 'Method not allowed.' });
  } catch (error) {
    console.error('chatConversations error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
