const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const DISHES_BUCKET = process.env.DISHES_BUCKET;
const REGION =
  process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'eu-north-1';
const PUBLIC_BASE_URL = process.env.DISHES_PUBLIC_BASE_URL || '';
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
  const safe = String(fileName || 'dish.jpg')
    .trim()
    .replace(/[^\w.\-]/g, '_');
  return safe || 'dish.jpg';
}

function resolveContentType(contentType, fileName) {
  const incoming = String(contentType || '').trim().toLowerCase();
  if (incoming) return incoming;
  const lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.jpeg') || lower.endsWith('.jpg')) return 'image/jpeg';
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

  if (!DISHES_BUCKET) {
    return response(500, {
      message: 'Server misconfiguration: DISHES_BUCKET is not set.',
    });
  }

  try {
    const body = parseBody(event);
    const dishId = String(body.dishId || '').trim();
    const rawFileName = cleanFileName(body.fileName);
    const contentType = resolveContentType(body.contentType, rawFileName);

    if (!dishId) {
      return response(400, { message: 'Missing required field: dishId.' });
    }

    const key = `dishes/${dishId}/${rawFileName}`;
    const uploadUrl = await getSignedUrl(
      s3,
      new PutObjectCommand({
        Bucket: DISHES_BUCKET,
        Key: key,
        ContentType: contentType,
        //ACL: 'public-read',
      }),
      { expiresIn: 15 * 60 },
    );

    return response(200, {
      uploadUrl,
      fileUrl: buildPublicFileUrl(DISHES_BUCKET, key),
      key,
      headers: {
        'Content-Type': contentType,
        //'x-amz-acl': 'public-read',
      },
    });
  } catch (error) {
    console.error('dishesUploadUrl error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};
