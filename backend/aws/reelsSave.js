const {
  DynamoDBClient,
  PutItemCommand,
  UpdateItemCommand,
} = require('@aws-sdk/client-dynamodb');

const ddb = new DynamoDBClient({});
const REELS_TABLE = process.env.REELS_TABLE;
const USERS_TABLE = process.env.USERS_TABLE || 'users';
const FALLBACK_TABLES = String(process.env.REELS_FALLBACK_TABLES || '')
  .split(',')
  .map((table) => table.trim())
  .filter(Boolean);
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
  if (value == null) {
    return fallback;
  }
  return String(value).trim();
}

function asNumber(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function asBool(value, fallback = false) {
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true' || normalized === '1') {
      return true;
    }
    if (normalized === 'false' || normalized === '0') {
      return false;
    }
  }
  if (typeof value === 'number') {
    return value !== 0;
  }
  return fallback;
}

function toReel(body) {
  const createdAt = asString(body.createdAt) || new Date().toISOString();
  return {
    id: asString(body.id),
    creatorId: asString(body.creatorId),
    creatorName: asString(body.creatorName, '@cook'),
    creatorImageUrl: asString(body.creatorImageUrl),
    title: asString(body.title, 'Cooking Reel'),
    description: asString(body.description, 'Short cooking clip'),
    imageUrl: asString(body.imageUrl),
    videoPath: asString(body.videoPath),
    audioLabel: asString(body.audioLabel, 'Original Audio'),
    likes: asNumber(body.likes, 0),
    comments: asNumber(body.comments, 0),
    shares: asNumber(body.shares, 0),
    isMine: asBool(body.isMine, false),
    isFollowing: asBool(body.isFollowing, false),
    isLiked: asBool(body.isLiked, false),
    isPaused: asBool(body.isPaused, false),
    isBookmarked: asBool(body.isBookmarked, false),
    isDraft: asBool(body.isDraft, false),
    commentItems: Array.isArray(body.commentItems) ? body.commentItems.map(c => ({
      id: asString(c.id),
      userId: asString(c.userId),
      userName: asString(c.userName),
      userImageUrl: asString(c.userImageUrl),
      text: asString(c.text),
      createdAt: asString(c.createdAt)
    })) : [],
    createdAt,
  };
}

async function updateLikeStats(body, reel) {
  const likeDelta = Math.trunc(asNumber(body.likeDelta, 0));
  if (likeDelta === 0 || !USERS_TABLE) return;
  const safeDelta = likeDelta > 0 ? 1 : -1;
  const now = new Date().toISOString();

  const updates = [];
  if (reel.creatorId) {
    updates.push({
      userId: reel.creatorId,
      field: 'reelLikesCount',
    });
  }
  const likedByUserId = asString(body.likedByUserId);
  if (likedByUserId) {
    updates.push({
      userId: likedByUserId,
      field: 'likedReelsCount',
    });
  }

  for (const update of updates) {
    try {
      await ddb.send(
        new UpdateItemCommand({
          TableName: USERS_TABLE,
          Key: { id: { S: update.userId } },
          UpdateExpression:
            'SET #updatedAt = :updatedAt, #counter = if_not_exists(#counter, :zero) + :delta',
          ConditionExpression:
            safeDelta < 0
              ? 'attribute_exists(#counter) AND #counter >= :one'
              : undefined,
          ExpressionAttributeNames: {
            '#updatedAt': 'updatedAt',
            '#counter': update.field,
          },
          ExpressionAttributeValues: {
            ':updatedAt': { S: now },
            ':zero': { N: '0' },
            ':one': { N: '1' },
            ':delta': { N: String(safeDelta) },
          },
        }),
      );
    } catch (error) {
      if (error?.name === 'ConditionalCheckFailedException') {
        continue;
      }
      console.warn('Failed to update reel like stats:', error);
    }
  }
}

function toDynamoItem(reel) {
  return {
    id: { S: reel.id },
    creatorId: { S: reel.creatorId },
    creatorName: { S: reel.creatorName },
    creatorImageUrl: { S: reel.creatorImageUrl },
    title: { S: reel.title },
    description: { S: reel.description },
    imageUrl: { S: reel.imageUrl },
    videoPath: { S: reel.videoPath },
    audioLabel: { S: reel.audioLabel },
    likes: { N: String(reel.likes) },
    comments: { N: String(reel.comments) },
    shares: { N: String(reel.shares) },
    isMine: { BOOL: reel.isMine },
    isFollowing: { BOOL: reel.isFollowing },
    isLiked: { BOOL: reel.isLiked },
    isPaused: { BOOL: reel.isPaused },
    isBookmarked: { BOOL: reel.isBookmarked },
    isDraft: { BOOL: reel.isDraft },
    commentItems: {
      L: reel.commentItems.map(c => ({
        M: {
          id: { S: c.id },
          userId: { S: c.userId },
          userName: { S: c.userName },
          userImageUrl: { S: c.userImageUrl },
          text: { S: c.text },
          createdAt: { S: c.createdAt }
        }
      }))
    },
    createdAt: { S: reel.createdAt },
  };
}

async function putReelWithFallbacks(item) {
  const tableNames = Array.from(
    new Set([REELS_TABLE, ...FALLBACK_TABLES].filter(Boolean)),
  );
  let lastError = null;

  for (const tableName of tableNames) {
    try {
      await ddb.send(
        new PutItemCommand({
          TableName: tableName,
          Item: item,
        }),
      );
      return;
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
  throw new Error('No writable reels table was found.');
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
    const body = parseBody(event);
    const reel = toReel(body);

    if (!reel.id || !reel.videoPath) {
      return response(400, {
        message: 'Missing required fields: id and videoPath are required.',
      });
    }

    await putReelWithFallbacks(toDynamoItem(reel));
    await updateLikeStats(body, reel);
    return response(200, { reel });
  } catch (error) {
    console.error('reelsSave error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
