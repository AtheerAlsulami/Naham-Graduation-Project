# AWS Lambda Step 4: Auth Backend Setup

هذا الدليل يشرح خطوة بخطوة إنشاء وظائف Lambda والمسارات المطلوبة في API Gateway للمصادقة.

## 1. إنشاء IAM Role للـ Lambda

1. افتح AWS Console.
2. اذهب إلى `IAM > Roles > Create role`.
3. اختر `Lambda` كنوع الـ trusted entity.
4. أضف الصلاحيات التالية:
   - `AWSLambdaBasicExecutionRole`
   - `AmazonDynamoDBFullAccess` (لمرحلة التطوير)
   - `AmazonS3FullAccess` إذا كنت ستستخدم رفع الصور لاحقًا.
5. سمّ الدور مثلاً: `NahamLambdaExecutionRole`.

## 2. إنشاء جدول DynamoDB للمستخدمين

1. اذهب إلى `DynamoDB > Tables > Create table`.
2. اسم الجدول: `naham_users`.
3. Partition key: `id` (String).
4. يمكن إضافة Global Secondary Index لاحقًا على `email` إذا تريد البحث السريع.
5. اترك الإعدادات الافتراضية.

## 3. إنشاء أول وظيفة Lambda: `AuthRegister`

1. اذهب إلى `Lambda > Create function`.
2. اختر `Author from scratch`.
3. اسم الوظيفة: `NahamAuthRegister`.
4. Runtime: `Node.js 20.x` أو `Python 3.11`.
5. اختر الـ IAM role الذي أنشأته.

### الكود المقترح لـ Node.js

```js
const { DynamoDBClient, PutItemCommand, QueryCommand } = require('@aws-sdk/client-dynamodb');
const crypto = require('crypto');

const ddb = new DynamoDBClient({});
const USERS_TABLE = process.env.USERS_TABLE;

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

exports.handler = async (event) => {
  const body = JSON.parse(event.body);
  const { name, email, password, phone, role } = body;

  if (!name || !email || !password || !role) {
    return { statusCode: 400, body: JSON.stringify({ message: 'Missing required fields.' }) };
  }

  const emailLower = email.toLowerCase().trim();
  const existing = await ddb.send(new QueryCommand({
    TableName: USERS_TABLE,
    IndexName: 'email-index',
    KeyConditionExpression: 'email = :email',
    ExpressionAttributeValues: { ':email': { S: emailLower } },
  }));

  if (existing.Count > 0) {
    return { statusCode: 409, body: JSON.stringify({ message: 'Email already exists.' }) };
  }

  const userId = `user_${Date.now()}`;
  const hashedPassword = hashPassword(password);
  const now = new Date().toISOString();

  const item = {
    id: { S: userId },
    name: { S: name },
    email: { S: emailLower },
    passwordHash: { S: hashedPassword },
    phone: { S: phone ?? '' },
    role: { S: role },
    createdAt: { S: now },
  };

  await ddb.send(new PutItemCommand({ TableName: USERS_TABLE, Item: item }));

  return {
    statusCode: 200,
    body: JSON.stringify({
      user: {
        id: userId,
        name,
        email: emailLower,
        phone: phone ?? '',
        role,
        createdAt: now,
      },
      accessToken: userId,
      refreshToken: userId,
    }),
  };
};
```

### الملاحظات

- هذا الكود هو نموذج مبدئي، ويمكن تحديثه لاحقًا لتحسين الأمان.
- يمكنك إنشاء مؤشر ثانوي على `email` باسم `email-index` لبحث أسرع.

## 4. إنشاء وظيفة Lambda: `AuthLogin`

1. أنشئ وظيفة جديدة اسمها `NahamAuthLogin`.
2. استخدم نفس الدور.
3. عيّن متغير البيئة `USERS_TABLE` إلى `naham_users`.

### الكود المقترح

```js
const { DynamoDBClient, QueryCommand } = require('@aws-sdk/client-dynamodb');
const crypto = require('crypto');

const ddb = new DynamoDBClient({});
const USERS_TABLE = process.env.USERS_TABLE;

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

exports.handler = async (event) => {
  const body = JSON.parse(event.body);
  const { email, password } = body;

  if (!email || !password) {
    return { statusCode: 400, body: JSON.stringify({ message: 'Missing required fields.' }) };
  }

  const emailLower = email.toLowerCase().trim();
  const result = await ddb.send(new QueryCommand({
    TableName: USERS_TABLE,
    IndexName: 'email-index',
    KeyConditionExpression: 'email = :email',
    ExpressionAttributeValues: { ':email': { S: emailLower } },
  }));

  if (!result.Items || result.Items.length === 0) {
    return { statusCode: 401, body: JSON.stringify({ message: 'Invalid credentials.' }) };
  }

  const user = result.Items[0];
  const storedHash = user.passwordHash.S;
  const attemptHash = hashPassword(password);

  if (storedHash !== attemptHash) {
    return { statusCode: 401, body: JSON.stringify({ message: 'Invalid credentials.' }) };
  }

  return {
    statusCode: 200,
    body: JSON.stringify({
      user: {
        id: user.id.S,
        name: user.name.S,
        email: user.email.S,
        phone: user.phone.S,
        role: user.role.S,
        createdAt: user.createdAt.S,
      },
      accessToken: user.id.S,
      refreshToken: user.id.S,
    }),
  };
};
```

## 5. إنشاء وظيفة Lambda: `AuthGoogleSignin`

1. أنشئ وظيفة باسم `NahamAuthGoogleSignin`.
2. أضف متغير البيئة `USERS_TABLE`.
3. أضف أيضاً متغير `GOOGLE_CLIENT_ID` إذا تريد التحقق من هوية التوكن.

### الكود المقترح

```js
const { DynamoDBClient, QueryCommand, PutItemCommand, UpdateItemCommand } = require('@aws-sdk/client-dynamodb');
const fetch = require('node-fetch');

const ddb = new DynamoDBClient({});
const USERS_TABLE = process.env.USERS_TABLE;
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;

exports.handler = async (event) => {
  const body = JSON.parse(event.body);
  const { idToken, role } = body;

  if (!idToken || !role) {
    return { statusCode: 400, body: JSON.stringify({ message: 'Missing idToken or role.' }) };
  }

  const response = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
  if (!response.ok) {
    return { statusCode: 401, body: JSON.stringify({ message: 'Invalid Google token.' }) };
  }

  const payload = await response.json();
  if (payload.aud !== GOOGLE_CLIENT_ID) {
    return { statusCode: 401, body: JSON.stringify({ message: 'Google token does not match client.' }) };
  }

  const email = payload.email.toLowerCase();
  const name = payload.name || email.split('@')[0];
  const picture = payload.picture || '';

  const existing = await ddb.send(new QueryCommand({
    TableName: USERS_TABLE,
    IndexName: 'email-index',
    KeyConditionExpression: 'email = :email',
    ExpressionAttributeValues: { ':email': { S: email } },
  }));

  let user;
  if (existing.Items && existing.Items.length > 0) {
    user = existing.Items[0];
    await ddb.send(new UpdateItemCommand({
      TableName: USERS_TABLE,
      Key: { id: { S: user.id.S } },
      UpdateExpression: 'SET name = :name, profileImageUrl = :picture',
      ExpressionAttributeValues: {
        ':name': { S: name },
        ':picture': { S: picture },
      },
    }));
  } else {
    const userId = `user_${Date.now()}`;
    const now = new Date().toISOString();
    await ddb.send(new PutItemCommand({
      TableName: USERS_TABLE,
      Item: {
        id: { S: userId },
        name: { S: name },
        email: { S: email },
        role: { S: role },
        profileImageUrl: { S: picture },
        createdAt: { S: now },
      },
    }));
    user = { id: { S: userId }, name: { S: name }, email: { S: email }, role: { S: role }, profileImageUrl: { S: picture }, createdAt: { S: now } };
  }

  return {
    statusCode: 200,
    body: JSON.stringify({
      user: {
        id: user.id.S,
        name: user.name.S,
        email: user.email.S,
        role: user.role.S,
        profileImageUrl: user.profileImageUrl.S,
        createdAt: user.createdAt.S,
      },
      accessToken: user.id.S,
      refreshToken: user.id.S,
    }),
  };
};
```

## 6. ربط الـ Lambda بـ API Gateway

1. اذهب إلى `API Gateway > HTTP APIs > Create API`.
2. اختر `Add integration` ثم Lambda.
3. أضف هذه الطرق:
   - `POST /auth/register` → `NahamAuthRegister`
   - `POST /auth/login` → `NahamAuthLogin`
   - `POST /auth/google-signin` → `NahamAuthGoogleSignin`
4. فعل CORS بشكل كامل.
5. احفظ عنوان الـ API.

## 7. تحديث التطبيق

1. افتح `lib/services/backend/backend_config.dart`.
2. عدّل `awsBaseUrl` إلى عنوان API Gateway النهائي.
3. شغّل التطبيق وجرب:
   - تسجيل حساب جديد
   - تسجيل دخول
   - تسجيل دخول Google

## 8. اختبار فوري

- افتح Postman أو Insomnia.
- جرّب `POST /auth/register` و `POST /auth/login` و `POST /auth/google-signin`.
- تأكد أن الاستجابة تحتوي على `user` و `accessToken`.

---

## ما سنفعله الآن

سأبدأ معك في تنفيذ الخطوة الرابعة من المسار الأول عبر:

1. إنشاء Lambda functions الخاصة بالمصادقة.
2. ربطها بمسارات API Gateway.
3. اختبارها والتأكد أن التطبيق يتصل بها.

إذا تريد، أبدأ الآن بإنشاء ملفات Lambda الثلاثة هذه في المشروع ونعمل عليها واحدة تلو الأخرى.
