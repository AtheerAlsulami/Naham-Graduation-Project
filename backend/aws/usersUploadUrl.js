const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const USERS_BUCKET = process.env.USERS_BUCKET;
const REGION =
  process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'eu-north-1';
const PUBLIC_BASE_URL = process.env.USERS_PUBLIC_BASE_URL || '';
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
  if (typeof event.body === 'object') return event.body;
  throw new Error('Unsupported request body type.');
}

function cleanFileName(fileName) {
  const safe = String(fileName || 'document.pdf')
    .trim()
    .replace(/[^\w.\-]/g, '_');
  return safe || 'document.pdf';
}

function resolveContentType(contentType, fileName) {
  const incoming = String(contentType || '').trim().toLowerCase();
  if (incoming) return incoming;
  const lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
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

  if (!USERS_BUCKET) {
    return response(500, {
      message: 'Server misconfiguration: USERS_BUCKET is not set.',
    });
  }

  try {
    const body = parseBody(event);
    const userId = String(body.userId || '').trim();
    const documentType = String(body.documentType || '').trim(); // 'id' or 'health'
    const rawFileName = cleanFileName(body.fileName);
    const contentType = resolveContentType(body.contentType, rawFileName);

    if (!userId) {
      return response(400, { message: 'Missing required field: userId.' });
    }
    if (!documentType || !['id', 'health'].includes(documentType)) {
      return response(400, { message: 'Invalid documentType. Must be "id" or "health".' });
    }

    const key = `users/${userId}/verification/${documentType}/${rawFileName}`;
    const uploadUrl = await getSignedUrl(
      s3,
      new PutObjectCommand({
        Bucket: USERS_BUCKET,
        Key: key,
        ContentType: contentType,
        //ACL: 'public-read',
      }),
      { expiresIn: 15 * 60 },
    );

    return response(200, {
      uploadUrl,
      fileUrl: buildPublicFileUrl(USERS_BUCKET, key),
      key,
      headers: {
        'Content-Type': contentType,
        //'x-amz-acl': 'public-read',
      },
    });
  } catch (error) {
    console.error('usersUploadUrl error:', error);
    return response(500, {
      message: 'Internal server error.',
      error: error.message || 'Unknown error',
    });
  }
};