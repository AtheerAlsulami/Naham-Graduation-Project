const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function loadAuthRegister({ existingItems = [] } = {}) {
  const calls = [];
  class PutItemCommand {
    constructor(input) {
      this.input = input;
    }
  }
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
      calls.push(command);
      if (command instanceof QueryCommand || command instanceof ScanCommand) {
        return { Items: existingItems };
      }
      return {};
    }
  }

  const source = fs.readFileSync(path.join(__dirname, 'authRegister.js'), 'utf8');
  const module = { exports: {} };
  const sandbox = {
    console,
    exports: module.exports,
    module,
    process: { env: { USERS_TABLE: 'users' } },
    require(request) {
      if (request === '@aws-sdk/client-dynamodb') {
        return { DynamoDBClient, PutItemCommand, QueryCommand, ScanCommand };
      }
      return require(request);
    },
  };
  vm.runInNewContext(source, sandbox, { filename: 'authRegister.js' });
  return { handler: module.exports.handler, calls, PutItemCommand };
}

test('authRegister creates a customer with normalized email and stable session tokens', async () => {
  const { handler, calls, PutItemCommand } = loadAuthRegister();

  const response = await handler({
    requestContext: { http: { method: 'POST' } },
    body: JSON.stringify({
      name: 'Customer',
      email: 'CUSTOMER@EXAMPLE.COM',
      password: 'secret123',
      phone: '+966500000000',
      role: 'customer',
    }),
  });

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.user.email, 'customer@example.com');
  assert.equal(payload.user.role, 'customer');
  assert.equal(payload.accessToken, payload.user.id);
  const put = calls.find((call) => call instanceof PutItemCommand);
  assert.ok(put, 'expected PutItemCommand');
  assert.equal(put.input.Item.email.S, 'customer@example.com');
  assert.notEqual(put.input.Item.passwordHash.S, 'secret123');
});

test('authRegister rejects duplicate email records', async () => {
  const { handler } = loadAuthRegister({
    existingItems: [{ id: { S: 'user_1' }, email: { S: 'cook@example.com' } }],
  });

  const response = await handler({
    requestContext: { http: { method: 'POST' } },
    body: JSON.stringify({
      name: 'Cook',
      email: 'cook@example.com',
      password: 'secret123',
      phone: '+966500000001',
      role: 'cook',
    }),
  });

  assert.equal(response.statusCode, 409);
  assert.match(JSON.parse(response.body).message, /Email already exists/);
});
