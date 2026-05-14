const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function loadHandler() {
  let scanInput;
  class ScanCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class DynamoDBClient {
    async send(command) {
      scanInput = command.input;
      return {
        Items: [
          {
            id: { S: 'older' },
            userId: { S: 'user_1' },
            userType: { S: 'cook' },
            title: { S: 'Older' },
            subtitle: { S: '' },
            type: { S: 'order' },
            data: { M: {} },
            isRead: { BOOL: true },
            createdAt: { S: '2026-05-07T09:00:00.000Z' },
          },
          {
            id: { S: 'newer' },
            userId: { S: 'user_1' },
            userType: { S: 'cook' },
            title: { S: 'Newer' },
            subtitle: { S: '' },
            type: { S: 'order' },
            data: { M: {} },
            isRead: { BOOL: false },
            createdAt: { S: '2026-05-07T10:00:00.000Z' },
          },
        ],
      };
    }
  }

  const source = fs.readFileSync(
    path.join(__dirname, 'notificationsList.js'),
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
        return { DynamoDBClient, ScanCommand };
      }
      return require(request);
    },
  };
  vm.runInNewContext(source, sandbox, { filename: 'notificationsList.js' });
  return {
    handler: module.exports.handler,
    getScanInput: () => scanInput,
  };
}

test('lists notifications scoped by user id and role with newest first', async () => {
  const { handler, getScanInput } = loadHandler();

  const response = await handler({
    requestContext: { http: { method: 'GET' } },
    queryStringParameters: {
      userId: 'user_1',
      userType: 'cook',
    },
  });

  assert.equal(response.statusCode, 200);
  assert.equal(getScanInput().ExpressionAttributeValues[':userId'].S, 'user_1');
  assert.equal(getScanInput().ExpressionAttributeValues[':userType'].S, 'cook');
  const payload = JSON.parse(response.body);
  assert.deepEqual(
    payload.notifications.map((notification) => notification.id),
    ['newer', 'older'],
  );
});
