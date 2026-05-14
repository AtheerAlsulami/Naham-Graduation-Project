const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function loadReelsSave() {
  const calls = [];
  class PutItemCommand {
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
      calls.push(command);
      return {};
    }
  }

  const source = fs.readFileSync(path.join(__dirname, 'reelsSave.js'), 'utf8');
  const module = { exports: {} };
  const sandbox = {
    console,
    exports: module.exports,
    module,
    process: { env: { REELS_TABLE: 'reels', USERS_TABLE: 'users' } },
    require(request) {
      if (request === '@aws-sdk/client-dynamodb') {
        return { DynamoDBClient, PutItemCommand, UpdateItemCommand };
      }
      return require(request);
    },
  };
  vm.runInNewContext(source, sandbox, { filename: 'reelsSave.js' });
  return { handler: module.exports.handler, calls, PutItemCommand, UpdateItemCommand };
}

test('reelsSave stores reel and increments creator and liker counters', async () => {
  const { handler, calls, PutItemCommand, UpdateItemCommand } = loadReelsSave();

  const response = await handler({
    requestContext: { http: { method: 'POST' } },
    body: JSON.stringify({
      id: 'reel_1',
      creatorId: 'cook_1',
      creatorName: 'Cook',
      videoPath: 'https://cdn.example.com/reel.mp4',
      likes: 6,
      likedByUserId: 'customer_1',
      likeDelta: 1,
    }),
  });

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.reel.id, 'reel_1');
  assert.equal(calls.filter((call) => call instanceof PutItemCommand).length, 1);
  const updates = calls.filter((call) => call instanceof UpdateItemCommand);
  assert.equal(updates.length, 2);
  assert.deepEqual(
    updates.map((call) => call.input.Key.id.S).sort(),
    ['cook_1', 'customer_1'],
  );
});

test('reelsSave rejects missing required id or videoPath', async () => {
  const { handler } = loadReelsSave();

  const response = await handler({
    requestContext: { http: { method: 'POST' } },
    body: JSON.stringify({ id: 'reel_1' }),
  });

  assert.equal(response.statusCode, 400);
  assert.match(JSON.parse(response.body).message, /id and videoPath/);
});
