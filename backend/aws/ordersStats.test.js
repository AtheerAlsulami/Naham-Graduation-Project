const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function loadLambda(fileName, sdkClasses, env = {}) {
  const source = fs.readFileSync(path.join(__dirname, fileName), 'utf8');
  const module = { exports: {} };
  const sandbox = {
    console,
    exports: module.exports,
    module,
    process: {
      env: {
        ORDERS_TABLE: 'orders',
        USERS_TABLE: 'users',
        ...env,
      },
    },
    require(request) {
      if (request === '@aws-sdk/client-dynamodb') {
        return sdkClasses;
      }
      return require(request);
    },
  };
  vm.runInNewContext(source, sandbox, { filename: fileName });
  return module.exports;
}

test('creating an order increments the customer placed-order counter', async () => {
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

  const lambda = loadLambda('ordersCreate.js', {
    DynamoDBClient,
    PutItemCommand,
    UpdateItemCommand,
  });

  const response = await lambda.handler({
    requestContext: { http: { method: 'POST' } },
    body: JSON.stringify({
      customerId: 'customer_1',
      customerName: 'Customer',
      cookId: 'cook_1',
      cookName: 'Cook',
      items: [{ dishId: 'dish_1', dishName: 'Kabsa', quantity: 1, price: 20 }],
    }),
  });

  assert.equal(response.statusCode, 200);
  const statsUpdate = calls.find((call) => call instanceof UpdateItemCommand);
  assert.ok(statsUpdate, 'expected a customer stats UpdateItemCommand');
  assert.equal(statsUpdate.input.TableName, 'users');
  assert.equal(JSON.stringify(statsUpdate.input.Key), JSON.stringify({ id: { S: 'customer_1' } }));
  assert.match(statsUpdate.input.UpdateExpression, /ordersPlacedCount/);
  const createdOrder = JSON.parse(response.body).order;
  assert.equal(createdOrder.status, 'pending_review');
  assert.match(createdOrder.approvalExpiresAt, /^20/);
  assert.equal(createdOrder.prepEstimateMinutes, 45);
  assert.ok(Array.isArray(createdOrder.statusHistory));
  assert.equal(createdOrder.statusHistory[0].status, 'pending_review');
});

test('accepting an order stores accepted time and delivery deadline', async () => {
  const calls = [];
  const orderItem = {
    id: { S: 'order_1' },
    displayId: { S: '#ORD-1' },
    customerId: { S: 'customer_1' },
    customerName: { S: 'Customer' },
    customerPhone: { S: '+966500000000' },
    cookId: { S: 'cook_1' },
    cookName: { S: 'Cook' },
    driverId: { S: 'driver_1' },
    driverName: { S: 'Driver' },
    driverPhone: { S: '+966511223344' },
    status: { S: 'in_progress' },
    dishId: { S: 'dish_1' },
    dishName: { S: 'Kabsa' },
    imageUrl: { S: '' },
    itemCount: { N: '1' },
    subtotal: { N: '20' },
    deliveryFee: { N: '5' },
    totalAmount: { N: '25' },
    cookEarnings: { N: '22' },
    note: { S: '' },
    itemsJson: { S: '[]' },
    deliveryAddressJson: { S: '{}' },
    paymentJson: { S: '{}' },
    trackingJson: { S: '{}' },
    rating: { N: '0' },
    createdAt: { S: '2026-05-08T09:00:00.000Z' },
    updatedAt: { S: '2026-05-08T09:00:00.000Z' },
    acceptedAt: { S: '2026-05-08T09:00:00.000Z' },
    outForDeliveryAt: { S: '' },
    deliveredAt: { S: '' },
    cancelledAt: { S: '' },
  };
  orderItem.status = { S: 'pending_review' };

  class GetItemCommand {
    constructor(input) {
      this.input = input;
    }
  }
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
      if (command instanceof GetItemCommand) {
        return { Item: orderItem };
      }
      return {};
    }
  }

  const lambda = loadLambda('ordersUpdateStatus.js', {
    DynamoDBClient,
    GetItemCommand,
    PutItemCommand,
    UpdateItemCommand,
  });

  const response = await lambda.handler({
    requestContext: { http: { method: 'POST' } },
    pathParameters: { id: 'order_1' },
    body: JSON.stringify({ action: 'accept' }),
  });

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.order.status, 'in_progress');
  assert.match(payload.order.acceptedAt, /^20/);
  assert.match(payload.order.deliveryDueAt, /^20/);
  assert.equal(payload.order.statusHistory.at(-1).status, 'in_progress');
});

test('cook cannot mark an order delivered directly', async () => {
  const calls = [];
  class GetItemCommand {
    constructor(input) {
      this.input = input;
    }
  }
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
      if (command instanceof GetItemCommand) {
        return {
          Item: {
            id: { S: 'order_1' },
            customerId: { S: 'customer_1' },
            cookId: { S: 'cook_1' },
            status: { S: 'out_for_delivery' },
            dishId: { S: 'dish_1' },
            dishName: { S: 'Kabsa' },
            itemCount: { N: '1' },
            subtotal: { N: '20' },
            deliveryFee: { N: '5' },
            totalAmount: { N: '25' },
            cookEarnings: { N: '22' },
            rating: { N: '0' },
            createdAt: { S: '2026-05-08T09:00:00.000Z' },
            updatedAt: { S: '2026-05-08T09:00:00.000Z' },
          },
        };
      }
      return {};
    }
  }

  const lambda = loadLambda('ordersUpdateStatus.js', {
    DynamoDBClient,
    GetItemCommand,
    PutItemCommand,
    UpdateItemCommand,
  });

  const response = await lambda.handler({
    requestContext: { http: { method: 'POST' } },
    pathParameters: { id: 'order_1' },
    body: JSON.stringify({ status: 'delivered' }),
  });

  assert.equal(response.statusCode, 400);
  assert.match(JSON.parse(response.body).message, /confirm_received/);
});

test('customer confirmation increments stats once and creates a payout record', async () => {
  const calls = [];
  class GetItemCommand {
    constructor(input) {
      this.input = input;
    }
  }
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
      if (command instanceof GetItemCommand) {
        return {
          Item: {
            id: { S: 'order_1' },
            customerId: { S: 'customer_1' },
            customerName: { S: 'Customer' },
            cookId: { S: 'cook_1' },
            cookName: { S: 'Cook' },
            status: { S: 'awaiting_customer_confirmation' },
            dishId: { S: 'dish_1' },
            dishName: { S: 'Kabsa' },
            itemCount: { N: '1' },
            subtotal: { N: '20' },
            deliveryFee: { N: '5' },
            totalAmount: { N: '25' },
            cookEarnings: { N: '22' },
            itemsJson: { S: JSON.stringify([{ dishId: 'dish_1', quantity: 2 }]) },
            rating: { N: '0' },
            createdAt: { S: '2026-05-08T09:00:00.000Z' },
            updatedAt: { S: '2026-05-08T09:00:00.000Z' },
            arrivedAt: { S: '2026-05-08T10:00:00.000Z' },
          },
        };
      }
      return {};
    }
  }

  const lambda = loadLambda('ordersUpdateStatus.js', {
    DynamoDBClient,
    GetItemCommand,
    PutItemCommand,
    UpdateItemCommand,
  }, {
    DISHES_TABLE: 'dishes',
    PAYOUTS_TABLE: 'payouts',
    NOTIFICATIONS_TABLE: 'notifications',
  });

  const response = await lambda.handler({
    requestContext: { http: { method: 'POST' } },
    pathParameters: { id: 'order_1' },
    body: JSON.stringify({ action: 'confirm_received' }),
  });

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.order.status, 'delivered');
  assert.match(payload.order.confirmedReceivedAt, /^20/);
  assert.match(payload.order.payoutId, /^payout_order_1_/);

  const statsUpdates = calls.filter((call) => call instanceof UpdateItemCommand);
  const cookStatsUpdate = statsUpdates.find((call) => call.input.TableName === 'users');
  assert.ok(cookStatsUpdate, 'expected a cook stats UpdateItemCommand');
  assert.match(cookStatsUpdate.input.UpdateExpression, /totalOrders/);
  const dishStatsUpdate = statsUpdates.find((call) => call.input.TableName === 'dishes');
  assert.ok(dishStatsUpdate, 'expected a dish stats UpdateItemCommand');
  const payoutPut = calls.find(
    (call) => call instanceof PutItemCommand && call.input.TableName === 'payouts',
  );
  assert.ok(payoutPut, 'expected a payout PutItemCommand');
  assert.equal(payoutPut.input.Item.status.S, 'pending_transfer');
});

test('confirming an already delivered order does not increment cook totals again', async () => {
  const calls = [];
  class GetItemCommand {
    constructor(input) {
      this.input = input;
    }
  }
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
      if (command instanceof GetItemCommand) {
        return {
          Item: {
            id: { S: 'order_1' },
            customerId: { S: 'customer_1' },
            cookId: { S: 'cook_1' },
            status: { S: 'delivered' },
            dishId: { S: 'dish_1' },
            dishName: { S: 'Kabsa' },
            itemCount: { N: '1' },
            subtotal: { N: '20' },
            deliveryFee: { N: '5' },
            totalAmount: { N: '25' },
            cookEarnings: { N: '22' },
            rating: { N: '0' },
            createdAt: { S: '2026-05-08T09:00:00.000Z' },
            updatedAt: { S: '2026-05-08T09:00:00.000Z' },
            deliveredAt: { S: '2026-05-08T10:00:00.000Z' },
          },
        };
      }
      return {};
    }
  }

  const lambda = loadLambda('ordersUpdateStatus.js', {
    DynamoDBClient,
    GetItemCommand,
    PutItemCommand,
    UpdateItemCommand,
  });

  const response = await lambda.handler({
    requestContext: { http: { method: 'POST' } },
    pathParameters: { id: 'order_1' },
    body: JSON.stringify({ action: 'confirm_received' }),
  });

  assert.equal(response.statusCode, 200);
  assert.equal(calls.filter((call) => call instanceof UpdateItemCommand).length, 0);
});

test('late nudge is rejected before delivery due time and accepted after it', async () => {
  const calls = [];
  class GetItemCommand {
    constructor(input) {
      this.input = input;
    }
  }
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
      if (command instanceof GetItemCommand) {
        return {
          Item: {
            id: { S: 'order_1' },
            customerId: { S: 'customer_1' },
            cookId: { S: 'cook_1' },
            status: { S: 'out_for_delivery' },
            dishId: { S: 'dish_1' },
            dishName: { S: 'Kabsa' },
            itemCount: { N: '1' },
            subtotal: { N: '20' },
            deliveryFee: { N: '5' },
            totalAmount: { N: '25' },
            cookEarnings: { N: '22' },
            rating: { N: '0' },
            createdAt: { S: '2026-05-08T09:00:00.000Z' },
            updatedAt: { S: '2026-05-08T09:00:00.000Z' },
            deliveryDueAt: { S: '2026-05-08T10:00:00.000Z' },
          },
        };
      }
      return {};
    }
  }

  const lambda = loadLambda('ordersUpdateStatus.js', {
    DynamoDBClient,
    GetItemCommand,
    PutItemCommand,
    UpdateItemCommand,
  }, {
    NOW_ISO: '2026-05-08T09:59:00.000Z',
  });

  const tooEarly = await lambda.handler({
    requestContext: { http: { method: 'POST' } },
    pathParameters: { id: 'order_1' },
    body: JSON.stringify({ action: 'nudge_late' }),
  });
  assert.equal(tooEarly.statusCode, 409);

  const lateLambda = loadLambda('ordersUpdateStatus.js', {
    DynamoDBClient,
    GetItemCommand,
    PutItemCommand,
    UpdateItemCommand,
  }, {
    NOW_ISO: '2026-05-08T10:05:00.000Z',
    NOTIFICATIONS_TABLE: 'notifications',
  });

  const late = await lateLambda.handler({
    requestContext: { http: { method: 'POST' } },
    pathParameters: { id: 'order_1' },
    body: JSON.stringify({ action: 'nudge_late' }),
  });
  assert.equal(late.statusCode, 200);
  assert.equal(JSON.parse(late.body).order.nudgeCount, 1);
});

test('rating is rejected before delivery and accepted after delivery', async () => {
  const calls = [];
  let status = 'awaiting_customer_confirmation';
  class GetItemCommand {
    constructor(input) {
      this.input = input;
    }
  }
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
      if (command instanceof GetItemCommand) {
        return {
          Item: {
            id: { S: 'order_1' },
            customerId: { S: 'customer_1' },
            cookId: { S: 'cook_1' },
            status: { S: status },
            dishId: { S: 'dish_1' },
            dishName: { S: 'Kabsa' },
            itemCount: { N: '1' },
            subtotal: { N: '20' },
            deliveryFee: { N: '5' },
            totalAmount: { N: '25' },
            cookEarnings: { N: '22' },
            rating: { N: '0' },
            createdAt: { S: '2026-05-08T09:00:00.000Z' },
            updatedAt: { S: '2026-05-08T09:00:00.000Z' },
          },
        };
      }
      return {};
    }
  }

  const lambda = loadLambda('ordersUpdateStatus.js', {
    DynamoDBClient,
    GetItemCommand,
    PutItemCommand,
    UpdateItemCommand,
  });

  const rejected = await lambda.handler({
    requestContext: { http: { method: 'POST' } },
    pathParameters: { id: 'order_1' },
    body: JSON.stringify({ action: 'rate', cookRating: 5, serviceRating: 4 }),
  });
  assert.equal(rejected.statusCode, 409);

  status = 'delivered';
  const accepted = await lambda.handler({
    requestContext: { http: { method: 'POST' } },
    pathParameters: { id: 'order_1' },
    body: JSON.stringify({
      action: 'rate',
      cookRating: 5,
      serviceRating: 4,
      reviewComment: 'Great service',
    }),
  });
  assert.equal(accepted.statusCode, 200);
  const payload = JSON.parse(accepted.body);
  assert.equal(payload.order.cookRating, 5);
  assert.equal(payload.order.serviceRating, 4);
  assert.equal(payload.order.reviewComment, 'Great service');
  assert.ok(calls.some((call) => call instanceof UpdateItemCommand));
});

test('replacement request waits for cook approval before returning to progress', async () => {
  const calls = [];
  let status = 'issue_reported';
  class GetItemCommand {
    constructor(input) {
      this.input = input;
    }
  }
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
      if (command instanceof GetItemCommand) {
        return {
          Item: {
            id: { S: 'order_1' },
            customerId: { S: 'customer_1' },
            cookId: { S: 'cook_1' },
            status: { S: status },
            dishId: { S: 'dish_1' },
            dishName: { S: 'Kabsa' },
            itemCount: { N: '1' },
            subtotal: { N: '20' },
            deliveryFee: { N: '5' },
            totalAmount: { N: '25' },
            cookEarnings: { N: '22' },
            rating: { N: '0' },
            createdAt: { S: '2026-05-08T09:00:00.000Z' },
            updatedAt: { S: '2026-05-08T09:00:00.000Z' },
            replacementHistoryJson: { S: '[]' },
          },
        };
      }
      return {};
    }
  }

  const lambda = loadLambda('ordersUpdateStatus.js', {
    DynamoDBClient,
    GetItemCommand,
    PutItemCommand,
    UpdateItemCommand,
  });

  const requested = await lambda.handler({
    requestContext: { http: { method: 'POST' } },
    pathParameters: { id: 'order_1' },
    body: JSON.stringify({
      action: 'request_replacement',
      replacementItems: [{ dishId: 'dish_2', dishName: 'Mandi', quantity: 1, price: 30 }],
    }),
  });
  assert.equal(requested.statusCode, 200);
  assert.equal(JSON.parse(requested.body).order.status, 'replacement_pending_cook');

  status = 'replacement_pending_cook';
  const approved = await lambda.handler({
    requestContext: { http: { method: 'POST' } },
    pathParameters: { id: 'order_1' },
    body: JSON.stringify({ action: 'approve_replacement' }),
  });
  assert.equal(approved.statusCode, 200);
  assert.equal(JSON.parse(approved.body).order.status, 'in_progress');
});
