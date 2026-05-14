const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function loadHandler() {
  let updateInput;
  class UpdateItemCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class DynamoDBClient {
    async send(command) {
      updateInput = command.input;
      return {
        Attributes: {
          id: { S: command.input.Key.id.S },
          userId: { S: 'user_1' },
          userType: { S: 'customer' },
          title: { S: 'Order update' },
          subtitle: { S: '' },
          type: { S: 'order' },
          data: { M: {} },
          isRead: { BOOL: true },
          createdAt: { S: '2026-05-07T10:00:00.000Z' },
        },
      };
    }
  }

  const source = fs.readFileSync(
    path.join(__dirname, 'notificationsMarkRead.js'),
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
        return { DynamoDBClient, UpdateItemCommand };
      }
      return require(request);
    },
  };
  vm.runInNewContext(source, sandbox, { filename: 'notificationsMarkRead.js' });
  return {
    handler: module.exports.handler,
    getUpdateInput: () => updateInput,
  };
}

test('marks notification as read when notificationId is sent in a JSON body', async () => {
  const { handler, getUpdateInput } = loadHandler();

  const response = await handler({
    requestContext: { http: { method: 'POST' } },
    body: JSON.stringify({ notificationId: 'notif_1' }),
  });

  assert.equal(response.statusCode, 200);
  assert.equal(getUpdateInput().Key.id.S, 'notif_1');
  const payload = JSON.parse(response.body);
  assert.equal(payload.notification.isRead, true);
});
