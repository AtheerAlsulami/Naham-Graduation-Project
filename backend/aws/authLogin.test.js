const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

function userItem({
  id = 'user_1',
  email = 'salma@gmail.com',
  password = 'secret123',
  role = 'cook',
  accountStatus = 'active',
  cookStatus = 'approved',
  createdAt = '2026-05-07T00:00:00.000Z',
}) {
  return {
    id: { S: id },
    email: { S: email },
    name: { S: 'Salma' },
    phone: { S: '+966500000000' },
    role: { S: role },
    passwordHash: { S: hashPassword(password) },
    accountStatus: { S: accountStatus },
    status: { S: accountStatus },
    cookStatus: { S: cookStatus },
    createdAt: { S: createdAt },
  };
}

function loadAuthLogin({ tableItems }) {
  class QueryCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class ScanCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class DynamoDBClient {
    async send(command) {
      const items = tableItems[command.input.TableName] || [];
      return command instanceof QueryCommand ? { Items: items } : { Items: [] };
    }
  }

  const source = fs.readFileSync(path.join(__dirname, 'authLogin.js'), 'utf8');
  const module = { exports: {} };
  const sandbox = {
    console,
    exports: module.exports,
    module,
    process: { env: { USERS_TABLE: 'users' } },
    require(request) {
      if (request === '@aws-sdk/client-dynamodb') {
        return { DynamoDBClient, QueryCommand, ScanCommand };
      }
      return require(request);
    },
  };
  vm.runInNewContext(source, sandbox, { filename: 'authLogin.js' });
  return module.exports;
}

test('email login checks the password record even when a fallback table has the same user id', async () => {
  const authLogin = loadAuthLogin({
    tableItems: {
      users: [
        userItem({
          id: 'user_same',
          password: 'old-password',
          cookStatus: 'pending_verification',
        }),
      ],
      naham_users: [
        userItem({
          id: 'user_same',
          password: 'secret123',
          cookStatus: 'approved',
        }),
      ],
    },
  });

  const response = await authLogin.handler({
    requestContext: { http: { method: 'POST' } },
    body: JSON.stringify({
      email: 'salma@gmail.com',
      password: 'secret123',
    }),
  });

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.user.email, 'salma@gmail.com');
  assert.equal(payload.user.cookStatus, 'approved');
});
