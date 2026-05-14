const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function loadHandler() {
  let putInput;
  class PutItemCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class DynamoDBClient {
    async send(command) {
      putInput = command.input;
      return {};
    }
  }

  const source = fs.readFileSync(
    path.join(__dirname, 'notificationsSave.js'),
    'utf8',
  );
  const module = { exports: {} };
  const sandbox = {
    console,
    exports: module.exports,
    module,
    process: { env: { NOTIFICATIONS_TABLE: 'notifications' } },
    require(request) {
      if (request === '@aws-sdk/client-dynamodb') {
        return { DynamoDBClient, PutItemCommand };
      }
      return require(request);
    },
  };
  vm.runInNewContext(source, sandbox, { filename: 'notificationsSave.js' });
  return {
    handler: module.exports.handler,
    getPutInput: () => putInput,
  };
}

test('creates a notification without external runtime dependencies', async () => {
  const { handler, getPutInput } = loadHandler();

  const response = await handler({
    requestContext: { http: { method: 'POST' } },
    body: JSON.stringify({
      userId: 'user_1',
      userType: 'admin',
      title: 'Cook approval request',
      subtitle: 'New cook uploaded documents',
      type: 'approval',
      data: { userId: 'cook_1' },
    }),
  });

  assert.equal(response.statusCode, 201);
  assert.equal(getPutInput().Item.userType.S, 'admin');
  assert.equal(getPutInput().Item.isRead.BOOL, false);
  const payload = JSON.parse(response.body);
  assert.equal(payload.notification.userType, 'admin');
  assert.equal(payload.notification.type, 'approval');
  assert.equal(typeof payload.notification.id, 'string');
});
