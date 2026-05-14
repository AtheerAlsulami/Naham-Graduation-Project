const {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
  QueryCommand,
  ScanCommand,
} = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});

const CONVERSATIONS_TABLE =
  process.env.CONVERSATIONS_TABLE || process.env.CHAT_TABLE || 'conversations';
const MESSAGES_TABLE =
  process.env.MESSAGES_TABLE || process.env.CHAT_MESSAGES_TABLE || 'messages';
const AWS_REGION =
  process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'unknown';

const CONVERSATIONS_FALLBACK_TABLES = parseCsv(
  process.env.CONVERSATIONS_FALLBACK_TABLES || process.env.CHAT_FALLBACK_TABLES,
);
const MESSAGES_FALLBACK_TABLES = parseCsv(process.env.MESSAGES_FALLBACK_TABLES);

const SUPPORT_PARTICIPANT_ID = '__support__';

const JSON_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'OPTIONS,GET,POST',
};

function parseCsv(value) {
  return String(value || '')
    .split(',')
    .map((part) => part.trim())
    .filter(isUsableTableName);
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

function tableNames(primary, fallbacks = [], defaults = []) {
  return Array.from(
    new Set([primary, ...fallbacks, ...defaults].filter(isUsableTableName)),
  );
}

function conversationsTableNames() {
  return tableNames(CONVERSATIONS_TABLE, CONVERSATIONS_FALLBACK_TABLES, [
    'conversations',
  ]);
}

function messagesTableNames() {
  return tableNames(MESSAGES_TABLE, MESSAGES_FALLBACK_TABLES, ['messages']);
}

function response(statusCode, payload) {
  return {
    statusCode,
    headers: JSON_HEADERS,
    body: JSON.stringify(payload),
  };
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
  throw new Error('Unsupported request body type.');
}

function asString(value, fallback = '') {
  if (value == null) return fallback;
  return String(value).trim();
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

function parseLimit(value, fallback = 300, max = 700) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(Math.trunc(parsed), max);
}

function isResourceNotFound(error) {
  return String(error?.name || '').toLowerCase().includes('resourcenotfound');
}

function isValidationException(error) {
  return String(error?.name || '').toLowerCase().includes('validation');
}

function isAdminRole(role) {
  return asString(role).toLowerCase() === 'admin';
}

function isSupportRole(role) {
  const normalized = asString(role).toLowerCase();
  return normalized === 'support' || normalized === 'admin';
}

function conversationStorageId(conversationId) {
  return `conv_${conversationId}`;
}

function conversationBusinessIdFromStorageId(storageId) {
  return asString(storageId).replace(/^conv_/, '');
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
  if (!attrValue?.M || typeof attrValue.M !== 'object') return {};
  const result = {};
  for (const [key, value] of Object.entries(attrValue.M)) {
    result[key] = pickString(value);
  }
  return result;
}

function pickNumberMap(attrValue) {
  if (!attrValue?.M || typeof attrValue.M !== 'object') return {};
  const result = {};
  for (const [key, value] of Object.entries(attrValue.M)) {
    const parsed = Number(value?.N);
    result[key] = Number.isFinite(parsed) ? parsed : 0;
  }
  return result;
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
    const numeric = Number(value);
    mapped[asString(key)] = { N: Number.isFinite(numeric) ? String(numeric) : '0' };
  }
  return { M: mapped };
}

function listToAttr(values) {
  return {
    L: (values || []).map((value) => ({ S: asString(value) })),
  };
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

function mapItemToMessage(item) {
  return {
    id: pickString(item.id),
    conversationId: pickString(item.conversationId),
    senderId: pickString(item.senderId),
    senderRole: pickString(item.senderRole),
    senderName: pickString(item.senderName),
    text: pickString(item.text),
    imageUrl: pickString(item.imageUrl),
    createdAt: pickString(item.createdAt, nowIso()),
  };
}

function mapToMessageItemSplit(message) {
  return {
    conversationId: { S: asString(message.conversationId) },
    createdAt: { S: asString(message.createdAt || nowIso()) },
    id: { S: asString(message.id) },
    senderId: { S: asString(message.senderId) },
    senderRole: { S: asString(message.senderRole) },
    senderName: { S: asString(message.senderName) },
    text: { S: asString(message.text) },
    imageUrl: { S: asString(message.imageUrl) },
  };
}

function mapToMessageItemLegacy(message) {
  return {
    id: { S: asString(message.id) },
    itemType: { S: 'message' },
    conversationId: { S: asString(message.conversationId) },
    senderId: { S: asString(message.senderId) },
    senderRole: { S: asString(message.senderRole) },
    senderName: { S: asString(message.senderName) },
    text: { S: asString(message.text) },
    imageUrl: { S: asString(message.imageUrl) },
    createdAt: { S: asString(message.createdAt || nowIso()) },
  };
}

async function getConversation(conversationId) {
  const names = conversationsTableNames();
  const storageId = conversationStorageId(conversationId);
  let lastError = null;

  for (const tableName of names) {
    try {
      const result = await ddb.send(
        new GetItemCommand({
          TableName: tableName,
          Key: {
            id: { S: storageId },
          },
        }),
      );
      if (result.Item) {
        return { conversation: mapItemToConversation(result.Item), tableName };
      }
    } catch (error) {
      if (isResourceNotFound(error)) {
        lastError = error;
        continue;
      }
      throw error;
    }
  }

  if (lastError) throw lastError;
  return { conversation: null, tableName: names[0] || CONVERSATIONS_TABLE };
}

async function putConversation(conversation) {
  const names = conversationsTableNames();
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
  throw new Error('No writable conversations table is available.');
}

async function queryMessagesFromLegacyTable(tableName, conversationId) {
  let lastEvaluatedKey;
  const items = [];
  do {
    const result = await ddb.send(
      new ScanCommand({
        TableName: tableName,
        ExclusiveStartKey: lastEvaluatedKey,
      }),
    );
    items.push(...(result.Items || []));
    lastEvaluatedKey = result.LastEvaluatedKey;
  } while (lastEvaluatedKey);

  return items
    .filter(
      (item) =>
        pickString(item.conversationId) === conversationId &&
        (pickString(item.itemType) === 'message' ||
          !!pickString(item.senderId) ||
          !!pickString(item.text)),
    )
    .map(mapItemToMessage);
}

async function queryMessages(conversationId, limit) {
  const names = messagesTableNames();
  let lastError = null;

  for (const tableName of names) {
    try {
      const result = await ddb.send(
        new QueryCommand({
          TableName: tableName,
          KeyConditionExpression: '#conversationId = :conversationId',
          ExpressionAttributeNames: {
            '#conversationId': 'conversationId',
          },
          ExpressionAttributeValues: {
            ':conversationId': { S: conversationId },
          },
          ScanIndexForward: false,
          Limit: limit,
        }),
      );
      const descending = (result.Items || []).map(mapItemToMessage);
      return descending.reverse();
    } catch (error) {
      if (isResourceNotFound(error)) {
        lastError = error;
        continue;
      }
      if (isValidationException(error)) {
        const legacyItems = await queryMessagesFromLegacyTable(
          tableName,
          conversationId,
        );
        legacyItems.sort((a, b) =>
          String(a.createdAt || '').localeCompare(String(b.createdAt || '')),
        );
        return legacyItems.slice(-limit);
      }
      throw error;
    }
  }

  if (lastError) throw lastError;
  throw new Error('No readable messages table is available.');
}

async function putMessage(message) {
  const names = messagesTableNames();
  let lastError = null;

  for (const tableName of names) {
    try {
      try {
        await ddb.send(
          new PutItemCommand({
            TableName: tableName,
            Item: mapToMessageItemSplit(message),
          }),
        );
        return;
      } catch (error) {
        if (!isValidationException(error)) {
          throw error;
        }
      }

      await ddb.send(
        new PutItemCommand({
          TableName: tableName,
          Item: mapToMessageItemLegacy(message),
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
  throw new Error('No writable messages table is available.');
}

function canAccessConversation(conversation, userId, role) {
  if (isAdminRole(role)) return conversation.isSupport;
  return Array.isArray(conversation.participantIds)
    ? conversation.participantIds.includes(userId)
    : false;
}

function updateUnreadMapAfterMessage(conversation, senderId, senderRole) {
  const unread = { ...(conversation.unreadByUser || {}) };
  const participants = Array.isArray(conversation.participantIds)
    ? conversation.participantIds
    : [];

  const bumpUnread = (key) => {
    unread[key] = asNumber(unread[key], 0) + 1;
  };
  const clearUnread = (key) => {
    unread[key] = 0;
  };

  if (conversation.isSupport) {
    const senderIsSupport =
      senderId === SUPPORT_PARTICIPANT_ID || isSupportRole(senderRole);
    if (senderIsSupport) {
      for (const participantId of participants) {
        if (participantId === SUPPORT_PARTICIPANT_ID) continue;
        if (participantId === senderId) {
          clearUnread(participantId);
          continue;
        }
        bumpUnread(participantId);
      }
      clearUnread(SUPPORT_PARTICIPANT_ID);
      return unread;
    }

    clearUnread(senderId);
    bumpUnread(SUPPORT_PARTICIPANT_ID);
    return unread;
  }

  for (const participantId of participants) {
    if (participantId === senderId) {
      clearUnread(participantId);
    } else {
      bumpUnread(participantId);
    }
  }
  return unread;
}

async function handleList(event) {
  const conversationId = asString(
    event?.pathParameters?.conversationId || event?.pathParameters?.id,
  );
  const query = event?.queryStringParameters || {};
  const userId = asString(query.userId);
  const userRole = asString(query.role || query.userRole);
  const limit = parseLimit(query.limit);

  if (!conversationId) {
    return response(400, { message: 'Missing conversationId in path.' });
  }
  if (!userId) {
    return response(400, { message: 'Missing userId query parameter.' });
  }

  const { conversation } = await getConversation(conversationId);
  if (!conversation) {
    return response(404, { message: 'Conversation not found.' });
  }
  if (!canAccessConversation(conversation, userId, userRole)) {
    return response(403, { message: 'Access denied for this conversation.' });
  }

  const messages = await queryMessages(conversationId, limit);
  return response(200, {
    items: messages,
    count: messages.length,
  });
}

async function handleSend(event) {
  const conversationId = asString(
    event?.pathParameters?.conversationId || event?.pathParameters?.id,
  );
  const body = parseBody(event);

  const senderId = asString(body.senderId);
  const senderRole = asString(body.senderRole || body.role);
  const senderName = asString(body.senderName, senderId);
  const text = asString(body.text);
  const imageUrl = asString(body.imageUrl);

  if (!conversationId) {
    return response(400, { message: 'Missing conversationId in path.' });
  }
  if (!senderId) {
    return response(400, { message: 'Missing required field: senderId.' });
  }
  if (!text && !imageUrl) {
    return response(400, {
      message: 'Message payload is empty. Provide text or imageUrl.',
    });
  }

  const { conversation } = await getConversation(conversationId);
  if (!conversation) {
    return response(404, { message: 'Conversation not found.' });
  }

  const senderAllowed =
    canAccessConversation(conversation, senderId, senderRole) ||
    (conversation.isSupport && isSupportRole(senderRole));
  if (!senderAllowed) {
    return response(403, { message: 'Sender is not allowed in conversation.' });
  }

  const createdAt = nowIso();
  const message = {
    id: `msg_${conversationId}_${Date.now()}_${Math.random()
      .toString(36)
      .slice(2, 8)}`,
    conversationId,
    senderId,
    senderRole,
    senderName,
    text,
    imageUrl,
    createdAt,
  };

  const updatedConversation = {
    ...conversation,
    lastMessage: text || (imageUrl ? 'Image sent' : ''),
    lastMessageAt: createdAt,
    unreadByUser: updateUnreadMapAfterMessage(conversation, senderId, senderRole),
  };

  await putMessage(message);
  await putConversation(updatedConversation);

  return response(200, { message });
}

exports.handler = async (event) => {
  const method = requestMethod(event);
  if (method === 'OPTIONS') {
    return response(200, { ok: true });
  }

  try {
    console.info('chatMessages invoke', {
      method,
      region: AWS_REGION,
      conversationsTable: CONVERSATIONS_TABLE,
      messagesTable: MESSAGES_TABLE,
      conversationsFallback: CONVERSATIONS_FALLBACK_TABLES,
      messagesFallback: MESSAGES_FALLBACK_TABLES,
    });
    if (method === 'GET') return await handleList(event);
    if (method === 'POST') return await handleSend(event);
    return response(405, { message: 'Method not allowed.' });
  } catch (error) {
    console.error('chatMessages error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
