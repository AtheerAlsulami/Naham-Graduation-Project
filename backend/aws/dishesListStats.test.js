const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function attrString(value) {
  return { S: value };
}

function attrNumber(value) {
  return { N: String(value) };
}

function dishItem({ id, name }) {
  return {
    id: attrString(id),
    cookId: attrString('cook_1'),
    cookName: attrString('Cook'),
    name: attrString(name),
    description: attrString('Dish'),
    price: attrNumber(20),
    imageUrl: attrString('https://example.com/dish.jpg'),
    rating: attrNumber(4.5),
    reviewsCount: attrNumber(1),
    categoryId: attrString('main'),
    isAvailable: { BOOL: true },
    preparationTimeMin: attrNumber(20),
    preparationTimeMax: attrNumber(40),
    createdAt: attrString('2026-05-01T00:00:00.000Z'),
  };
}

function orderItem({ id, dishId, status, createdAt }) {
  return {
    id: attrString(id),
    customerId: attrString('customer_1'),
    cookId: attrString('cook_1'),
    status: attrString(status),
    dishId: attrString(dishId),
    itemsJson: attrString(
      JSON.stringify([{ dishId, dishName: dishId, quantity: 1, price: 20 }]),
    ),
    createdAt: attrString(createdAt),
    deliveredAt: attrString(createdAt),
  };
}

function loadDishesList({ itemsByTable }) {
  class ScanCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class GetObjectCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class S3Client {
    constructor(input) {
      this.input = input;
    }
  }
  class DynamoDBClient {
    async send(command) {
      return { Items: itemsByTable[command.input.TableName] || [] };
    }
  }

  const source = fs.readFileSync(path.join(__dirname, 'dishesList.js'), 'utf8');
  const module = { exports: {} };
  const sandbox = {
    console,
    exports: module.exports,
    module,
    process: {
      env: {
        DISHES_TABLE: 'dishes',
        ORDERS_TABLE: 'orders',
      },
    },
    require(request) {
      if (request === '@aws-sdk/client-dynamodb') {
        return { DynamoDBClient, ScanCommand };
      }
      if (request === '@aws-sdk/client-s3') {
        return { S3Client, GetObjectCommand };
      }
      if (request === '@aws-sdk/s3-request-presigner') {
        return { getSignedUrl: async () => '' };
      }
      return require(request);
    },
  };
  vm.runInNewContext(source, sandbox, { filename: 'dishesList.js' });
  return module.exports;
}

test('lists cook dishes with total and current-month order counts sorted by monthly orders', async () => {
  const currentMonth = new Date().toISOString().slice(0, 7);
  const lambda = loadDishesList({
    itemsByTable: {
      dishes: [
        dishItem({ id: 'dish_less', name: 'Less Ordered' }),
        dishItem({ id: 'dish_more', name: 'More Ordered' }),
      ],
      orders: [
        orderItem({
          id: 'order_1',
          dishId: 'dish_more',
          status: 'delivered',
          createdAt: `${currentMonth}-04T10:00:00.000Z`,
        }),
        orderItem({
          id: 'order_2',
          dishId: 'dish_more',
          status: 'delivered',
          createdAt: `${currentMonth}-05T10:00:00.000Z`,
        }),
        orderItem({
          id: 'order_3',
          dishId: 'dish_less',
          status: 'delivered',
          createdAt: '2026-01-05T10:00:00.000Z',
        }),
        orderItem({
          id: 'order_4',
          dishId: 'dish_less',
          status: 'cancelled',
          createdAt: `${currentMonth}-06T10:00:00.000Z`,
        }),
      ],
    },
  });

  const response = await lambda.handler({
    requestContext: { http: { method: 'GET' } },
    queryStringParameters: {
      cookId: 'cook_1',
      sort: 'orders_current_month',
    },
  });

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.items[0].id, 'dish_more');
  assert.equal(payload.items[0].currentMonthOrders, 2);
  assert.equal(payload.items[0].totalOrders, 2);
  assert.equal(payload.items[1].id, 'dish_less');
  assert.equal(payload.items[1].currentMonthOrders, 0);
  assert.equal(payload.items[1].totalOrders, 1);
});
