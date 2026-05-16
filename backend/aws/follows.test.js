const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function loadFollows({ sends }) {
  class PutItemCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class DeleteItemCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class QueryCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class UpdateItemCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class DynamoDBClient {
    async send(command) {
      sends.push(command);
      return {};
    }
  }

  const source = fs.readFileSync(path.join(__dirname, 'follows.js'), 'utf8');
  const module = { exports: {} };
  const sandbox = {
    console,
    exports: module.exports,
    module,
    process: {
      env: {
        FOLLOWS_TABLE: 'follows',
        USERS_TABLE: 'users',
      },
    },
    require(request) {
      if (request === '@aws-sdk/client-dynamodb') {
        return {
          DynamoDBClient,
          PutItemCommand,
          DeleteItemCommand,
          QueryCommand,
          UpdateItemCommand,
        };
      }
      return require(request);
    },
  };
  vm.runInNewContext(source, sandbox, { filename: 'follows.js' });
  return {
    handler: module.exports.handler,
    PutItemCommand,
    DeleteItemCommand,
    UpdateItemCommand,
  };
}

test('following a cook stores the relationship and increments both counters', async () => {
  const sends = [];
  const { handler, PutItemCommand, UpdateItemCommand } = loadFollows({ sends });

  const response = await handler({
    requestContext: { http: { method: 'POST' } },
    body: JSON.stringify({ customerId: 'customer_1', cookId: 'cook_1' }),
  });

  assert.equal(response.statusCode, 200);
  assert.equal(sends.filter((call) => call instanceof PutItemCommand).length, 1);
  const updates = sends.filter((call) => call instanceof UpdateItemCommand);
  assert.equal(updates.length, 2);
  assert.equal(updates[0].input.ExpressionAttributeNames['#counter'], 'followingCooksCount');
  assert.equal(updates[1].input.ExpressionAttributeNames['#counter'], 'followersCount');
  for (const update of updates) {
    assert.equal(update.input.ConditionExpression, undefined);
    assert.equal(
      Object.hasOwn(update.input.ExpressionAttributeValues, ':one'),
      false,
    );
  }
});

test('unfollowing a cook removes the relationship and decrements both counters safely', async () => {
  const sends = [];
  const { handler, DeleteItemCommand, UpdateItemCommand } = loadFollows({ sends });

  const response = await handler({
    requestContext: { http: { method: 'DELETE' } },
    body: JSON.stringify({ customerId: 'customer_1', cookId: 'cook_1' }),
  });

  assert.equal(response.statusCode, 200);
  assert.equal(sends.filter((call) => call instanceof DeleteItemCommand).length, 1);
  const updates = sends.filter((call) => call instanceof UpdateItemCommand);
  assert.equal(updates.length, 2);
  assert.equal(updates[0].input.ExpressionAttributeNames['#counter'], 'followingCooksCount');
  assert.equal(updates[1].input.ExpressionAttributeNames['#counter'], 'followersCount');
  for (const update of updates) {
    assert.equal(
      update.input.ConditionExpression,
      'attribute_exists(#counter) AND #counter >= :one',
    );
    assert.equal(
      Object.hasOwn(update.input.ExpressionAttributeValues, ':one'),
      true,
    );
  }
});

test('following a cook works when customerId and cookId are passed as query parameters', async () => {
  const sends = [];
  const { handler, PutItemCommand, UpdateItemCommand } = loadFollows({ sends });

  const response = await handler({
    requestContext: { http: { method: 'POST' } },
    queryStringParameters: {
      customerId: 'customer_1',
      cookId: 'cook_1',
    },
  });

  assert.equal(response.statusCode, 200);
  assert.equal(sends.filter((call) => call instanceof PutItemCommand).length, 1);
  const updates = sends.filter((call) => call instanceof UpdateItemCommand);
  assert.equal(updates.length, 2);
  assert.equal(updates[0].input.ExpressionAttributeNames['#counter'], 'followingCooksCount');
  assert.equal(updates[1].input.ExpressionAttributeNames['#counter'], 'followersCount');
});
