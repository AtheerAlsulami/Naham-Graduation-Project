const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const REELS_BUCKET = process.env.REELS_BUCKET;
const REGION = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'eu-north-1';
const PUBLIC_BASE_URL = process.env.REELS_PUBLIC_BASE_URL || '';
const s3 = new S3Client({ region: REGION });
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

function cleanFileName(fileName) {
  const safe = String(fileName || 'reel.mp4')
    .trim()
    .replace(/[^\w.\-]/g, '_');
  return safe || 'reel.mp4';
}

function resolveContentType(contentType, fileName) {
  const incoming = String(contentType || '').trim().toLowerCase();
  if (incoming) {
    return incoming;
  }
  const lower = fileName.toLowerCase();
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.webm')) return 'video/webm';
  return 'application/octet-stream';
}

function buildPublicFileUrl(bucket, key) {
  const keyPath = key
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/');

  const base = PUBLIC_BASE_URL.trim()
    ? PUBLIC_BASE_URL.trim().replace(/\/+$/, '')
    : `https://${bucket}.s3.${REGION}.amazonaws.com`;
  return `${base}/${keyPath}`;
}

exports.handler = async (event) => {
  if (event?.requestContext?.http?.method === 'OPTIONS') {
    return response(200, { ok: true });
  }

  if (!REELS_BUCKET) {
    return response(500, {
      message: 'Server misconfiguration: REELS_BUCKET is not set.',
    });
  }

  try {
    const body = parseBody(event);
    const reelId = String(body.reelId || '').trim();
    const rawFileName = cleanFileName(body.fileName);
    const contentType = resolveContentType(body.contentType, rawFileName);

    if (!reelId) {
      return response(400, { message: 'Missing required field: reelId.' });
    }

    const key = `cook_reels/${reelId}/${rawFileName}`;
    const uploadUrl = await getSignedUrl(
      s3,
      new PutObjectCommand({
        Bucket: REELS_BUCKET,
        Key: key,
        ContentType: contentType,
      }),
      { expiresIn: 15 * 60 },
    );

    return response(200, {
      uploadUrl,
      fileUrl: buildPublicFileUrl(REELS_BUCKET, key),
      key,
      headers: {
        'Content-Type': contentType,
      },
    });
  } catch (error) {
    console.error('reelsUploadUrl error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
