const {
  DynamoDBClient,
  DeleteItemCommand,
  DescribeTableCommand,
  ScanCommand,
} = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});
const REELS_TABLE = process.env.REELS_TABLE;
const FALLBACK_TABLES = String(process.env.REELS_FALLBACK_TABLES || '')
  .split(',')
  .map((table) => table.trim())
  .filter(Boolean);
const JSON_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'OPTIONS,DELETE',
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
      return {};
    }
  }
  if (typeof event.body === 'object') {
    return event.body;
  }
  return {};
}

function extractReelId(event) {
  const fromPath = event?.pathParameters?.id;
  if (typeof fromPath === 'string' && fromPath.trim()) {
    return fromPath.trim();
  }
  const body = parseBody(event);
  const fromBody = body.id;
  if (typeof fromBody === 'string' && fromBody.trim()) {
    return fromBody.trim();
  }
  return '';
}

function dynamoValueToAttribute(value) {
  if (!value || typeof value !== 'object') {
    return { S: '' };
  }
  if (typeof value.S === 'string') {
    return { S: value.S };
  }
  if (typeof value.N === 'string') {
    return { N: value.N };
  }
  if (typeof value.BOOL === 'boolean') {
    return { BOOL: value.BOOL };
  }
  if (value.NULL === true) {
    return { NULL: true };
  }
  return { S: '' };
}

async function getTableKeySchema(tableName) {
  const described = await ddb.send(
    new DescribeTableCommand({
      TableName: tableName,
    }),
  );
  const schema = described?.Table?.KeySchema ?? [];
  if (!Array.isArray(schema) || schema.length === 0) {
    throw new Error(`Table ${tableName} has no key schema.`);
  }
  return schema;
}

async function findAnyItemById(tableName, reelId) {
  let lastEvaluatedKey;

  do {
    const scan = await ddb.send(
      new ScanCommand({
        TableName: tableName,
        FilterExpression: '#id = :id',
        ExpressionAttributeNames: {
          '#id': 'id',
        },
        ExpressionAttributeValues: {
          ':id': { S: reelId },
        },
        ConsistentRead: true,
        ExclusiveStartKey: lastEvaluatedKey,
      }),
    );

    const items = scan.Items ?? [];
    if (items.length > 0) {
      return items[0];
    }
    lastEvaluatedKey = scan.LastEvaluatedKey;
  } while (lastEvaluatedKey);

  return null;
}

function buildDeleteKey({
  keySchema,
  reelId,
  foundItem,
}) {
  const key = {};

  for (const keyPart of keySchema) {
    const attrName = keyPart?.AttributeName;
    if (!attrName) {
      continue;
    }

    if (attrName === 'id') {
      key[attrName] = { S: reelId };
      continue;
    }

    const fromItem = foundItem ? foundItem[attrName] : null;
    if (!fromItem) {
      throw new Error(
        `Cannot build full delete key. Missing key attribute "${attrName}" on stored item.`,
      );
    }
    key[attrName] = dynamoValueToAttribute(fromItem);
  }

  if (Object.keys(key).length === 0) {
    throw new Error('Delete key is empty.');
  }
  return key;
}

async function deleteFromTable(tableName, reelId) {
  const keySchema = await getTableKeySchema(tableName);
  const foundItem = await findAnyItemById(tableName, reelId);
  if (!foundItem) {
    return false;
  }

  const key = buildDeleteKey({
    keySchema,
    reelId,
    foundItem,
  });

  await ddb.send(
    new DeleteItemCommand({
      TableName: tableName,
      Key: key,
    }),
  );
  return true;
}

async function deleteWithFallbacks(reelId) {
  const primaryTable = String(REELS_TABLE || '').trim();
  const fallbackTables = Array.from(
    new Set(
      FALLBACK_TABLES
        .map((table) => String(table || '').trim())
        .filter((table) => table && table !== primaryTable),
    ),
  );

  let primaryMissing = false;
  let deletedPrimary = false;
  try {
    deletedPrimary = await deleteFromTable(primaryTable, reelId);
    if (deletedPrimary) {
      return true;
    }
  } catch (error) {
    const code = (error?.name || '').toLowerCase();
    if (!code.includes('resourcenotfound')) {
      throw error;
    }
    primaryMissing = true;
  }

  let lastError = null;
  for (const tableName of fallbackTables) {
    try {
      const deleted = await deleteFromTable(tableName, reelId);
      if (deleted) {
        return true;
      }
    } catch (error) {
      const code = (error?.name || '').toLowerCase();
      if (code.includes('resourcenotfound')) {
        lastError = error;
        continue;
      }
      throw error;
    }
  }

  if (primaryMissing && lastError) {
    throw lastError;
  }
  return false;
}

exports.handler = async (event) => {
  if (event?.requestContext?.http?.method === 'OPTIONS') {
    return response(200, { ok: true });
  }

  if (!REELS_TABLE) {
    return response(500, {
      message: 'Server misconfiguration: REELS_TABLE is not set.',
    });
  }

  try {
    const reelId = extractReelId(event);
    if (!reelId) {
      return response(400, { message: 'Missing reel id.' });
    }

    const deleted = await deleteWithFallbacks(reelId);
    if (!deleted) {
      const searchedTables = Array.from(
        new Set(
          [REELS_TABLE, ...FALLBACK_TABLES]
            .map((table) => String(table || '').trim())
            .filter(Boolean),
        ),
      );
      return response(404, {
        message: 'Reel not found.',
        id: reelId,
        searchedTables,
      });
    }

    return response(200, {
      message: 'Reel deleted successfully.',
      id: reelId,
    });
  } catch (error) {
    console.error('reelsDelete error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
