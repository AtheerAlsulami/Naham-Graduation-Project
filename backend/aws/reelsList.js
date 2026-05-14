const { DynamoDBClient, ScanCommand } = require('@aws-sdk/client-dynamodb');

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
  'Access-Control-Allow-Methods': 'OPTIONS,GET',
};

function response(statusCode, payload) {
  return {
    statusCode,
    headers: JSON_HEADERS,
    body: JSON.stringify(payload),
  };
}

function pickString(attrValue, fallback = '') {
  return typeof attrValue?.S === 'string' ? attrValue.S : fallback;
}

function pickNumber(attrValue, fallback = 0) {
  if (typeof attrValue?.N !== 'string') {
    return fallback;
  }
  const parsed = Number(attrValue.N);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function pickBoolean(attrValue, fallback = false) {
  if (typeof attrValue?.BOOL === 'boolean') {
    return attrValue.BOOL;
  }
  return fallback;
}

function mapItemToReel(item) {
  return {
    id: pickString(item.id),
    creatorId: pickString(item.creatorId),
    creatorName: pickString(item.creatorName, '@cook'),
    creatorImageUrl: pickString(item.creatorImageUrl, ''),
    title: pickString(item.title, 'Cooking Reel'),
    description: pickString(item.description, 'Short cooking clip'),
    imageUrl: pickString(item.imageUrl, ''),
    videoPath: pickString(item.videoPath, ''),
    audioLabel: pickString(item.audioLabel, 'Original Audio'),
    likes: pickNumber(item.likes, 0),
    comments: pickNumber(item.comments, 0),
    shares: pickNumber(item.shares, 0),
    isMine: pickBoolean(item.isMine, false),
    isFollowing: pickBoolean(item.isFollowing, false),
    isLiked: pickBoolean(item.isLiked, false),
    isPaused: pickBoolean(item.isPaused, false),
    isBookmarked: pickBoolean(item.isBookmarked, false),
    isDraft: pickBoolean(item.isDraft, false),
    commentItems: item.commentItems?.L ? item.commentItems.L.map(c => {
      const m = c.M || {};
      return {
        id: pickString(m.id),
        userId: pickString(m.userId),
        userName: pickString(m.userName),
        userImageUrl: pickString(m.userImageUrl),
        text: pickString(m.text),
        createdAt: pickString(m.createdAt)
      };
    }) : [],
    createdAt: pickString(item.createdAt, new Date().toISOString()),
  };
}

async function scanReelsFromTable(tableName) {
  let lastEvaluatedKey;
  const results = [];
  do {
    const scanResult = await ddb.send(
      new ScanCommand({
        TableName: tableName,
        ExclusiveStartKey: lastEvaluatedKey,
      }),
    );
    results.push(...(scanResult.Items ?? []));
    lastEvaluatedKey = scanResult.LastEvaluatedKey;
  } while (lastEvaluatedKey);
  return results;
}

async function loadReels() {
  const tableNames = Array.from(
    new Set([REELS_TABLE, ...FALLBACK_TABLES].filter(Boolean)),
  );
  let lastError = null;

  for (const tableName of tableNames) {
    try {
      return await scanReelsFromTable(tableName);
    } catch (error) {
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
  return [];
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
    const sortOrder = (event?.queryStringParameters?.sort || 'newest')
      .toString()
      .toLowerCase();
    const newestFirst = sortOrder !== 'oldest';

    const rawItems = await loadReels();
    const reels = rawItems.map(mapItemToReel).sort((a, b) => {
      if (newestFirst) {
        return (b.createdAt || '').localeCompare(a.createdAt || '');
      }
      return (a.createdAt || '').localeCompare(b.createdAt || '');
    });

    return response(200, { reels });
  } catch (error) {
    console.error('reelsList error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
