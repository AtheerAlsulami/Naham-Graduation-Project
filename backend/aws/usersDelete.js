const { DynamoDBClient, DeleteItemCommand } = require('@aws-sdk/client-dynamodb');

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
  'Access-Control-Allow-Methods': 'OPTIONS,DELETE',
};

function response(statusCode, payload) {
  return {
    statusCode,
    headers: JSON_HEADERS,
    body: JSON.stringify(payload),
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

  try {
    const userId = String(event?.pathParameters?.id || '').trim();
    if (!userId) {
      return response(400, { message: 'Missing required path parameter: id.' });
    }

    let deletedCount = 0;
    let lastError = null;

    for (const tableName of FALLBACK_TABLES) {
      if (!tableName) continue;
      try {
        const result = await ddb.send(
          new DeleteItemCommand({
            TableName: tableName,
            Key: { id: { S: userId } },
            ReturnValues: 'ALL_OLD',
          }),
        );
        if (result.Attributes) {
          deletedCount += 1;
        }
      } catch (error) {
        const code = String(error?.name || '').toLowerCase();
        if (code.includes('resourcenotfound')) {
          lastError = error;
          continue;
        }
        throw error;
      }
    }

    if (deletedCount == 0) {
      if (lastError) {
        throw lastError;
      }
      return response(404, { message: 'User not found.', id: userId });
    }

    return response(200, {
      id: userId,
      deleted: true,
      deletedCount,
    });
  } catch (error) {
    console.error('usersDelete error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};

