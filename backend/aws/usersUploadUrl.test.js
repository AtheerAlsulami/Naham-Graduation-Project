const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function loadUsersUploadUrl() {
  let putObjectInput;
  class S3Client {
    constructor(input) {
      this.input = input;
    }
  }
  class PutObjectCommand {
    constructor(input) {
      this.input = input;
      putObjectInput = input;
    }
  }

  const source = fs.readFileSync(path.join(__dirname, 'usersUploadUrl.js'), 'utf8');
  const module = { exports: {} };
  const sandbox = {
    console,
    exports: module.exports,
    module,
    process: {
      env: {
        USERS_BUCKET: 'naham-users',
        AWS_REGION: 'eu-north-1',
        USERS_PUBLIC_BASE_URL: 'https://cdn.example.com',
      },
    },
    require(request) {
      if (request === '@aws-sdk/client-s3') {
        return { S3Client, PutObjectCommand };
      }
      if (request === '@aws-sdk/s3-request-presigner') {
        return {
          getSignedUrl: async () => 'https://s3.example.com/signed-put-url',
        };
      }
      return require(request);
    },
  };
  vm.runInNewContext(source, sandbox, { filename: 'usersUploadUrl.js' });
  return { handler: module.exports.handler, getPutObjectInput: () => putObjectInput };
}

test('usersUploadUrl returns signed upload URL and public verification file URL', async () => {
  const { handler, getPutObjectInput } = loadUsersUploadUrl();

  const response = await handler({
    requestContext: { http: { method: 'POST' } },
    body: JSON.stringify({
      userId: 'cook_1',
      documentType: 'id',
      fileName: 'my id.pdf',
      contentType: 'application/pdf',
    }),
  });

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.uploadUrl, 'https://s3.example.com/signed-put-url');
  assert.equal(payload.key, 'users/cook_1/verification/id/my_id.pdf');
  assert.equal(payload.fileUrl, 'https://cdn.example.com/users/cook_1/verification/id/my_id.pdf');
  assert.equal(payload.headers['Content-Type'], 'application/pdf');
  assert.equal(getPutObjectInput().Bucket, 'naham-users');
});

test('usersUploadUrl rejects unsupported documentType', async () => {
  const { handler } = loadUsersUploadUrl();

  const response = await handler({
    requestContext: { http: { method: 'POST' } },
    body: JSON.stringify({
      userId: 'cook_1',
      documentType: 'video',
      fileName: 'clip.mp4',
    }),
  });

  assert.equal(response.statusCode, 400);
  assert.match(JSON.parse(response.body).message, /documentType/);
});
