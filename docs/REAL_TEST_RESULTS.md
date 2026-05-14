# Unit Testing Table

| Tested Unit / Requirement | Test Scenario | Expected Result | Tested Code / Reference | Actual Result |
|---|---|---|---|---|
| AwsAuthService login | Login posts email/password through AwsApiClient and persists user/token session | Authenticated user is returned and SharedPreferences contains session data | `test/unit/aws_auth_service_test.dart`; `lib/services/aws/aws_auth_service.dart` | PASS |
| AwsAuthService register | Register sends customer/cook role payload and stores returned user | Registered user is persisted with role and cookStatus when present | `test/unit/aws_auth_service_test.dart`; `lib/services/aws/aws_auth_service.dart` | PASS |
| SharedPreferences session persistence | Read current user after login/register | Stored user is restored from `aws_current_user` | `test/unit/aws_auth_service_test.dart`; `lib/services/aws/aws_auth_service.dart` | PASS |
| Kitchen verification upload URL | Request signed upload URL for cook document | Upload URL, file URL, key, and headers are parsed | `test/unit/aws_auth_service_test.dart`; `lib/services/aws/aws_auth_service.dart` | PASS |
| AwsOrderService create order | Create order sends `/orders` payload and parses pending order | CustomerOrderModel has pending review status | `test/unit/aws_order_service_test.dart`; `lib/services/aws/aws_order_service.dart` | PASS |
| AwsOrderService confirm received | Send `confirm_received` to `/orders/{id}/status` | Order becomes delivered and payout id is parsed | `test/unit/aws_order_service_test.dart`; `lib/services/aws/aws_order_service.dart` | PASS |
| Rating validation | Backend 409 rating rejection is surfaced by AwsApiClient | Service throws AwsApiException for invalid rating operation | `test/unit/aws_order_service_test.dart`; `lib/services/aws/aws_order_service.dart` | PASS |
| AwsPricingService pricing endpoint | Parse Lambda pricing suggestion response | Suggested price, breakdown, market signal, and insights are parsed | `test/unit/aws_pricing_service_test.dart`; `lib/services/aws/aws_pricing_service.dart` | PASS |
| GroqPricingService | Post chat completion and parse suggested price | Groq response content becomes PricingSuggestion | `test/unit/groq_pricing_service_test.dart`; `lib/services/backend/groq_pricing_service.dart` | PASS |
| Reels like increment | Save reel with `likedByUserId` and `likeDelta: 1` | Request body contains increment metadata | `test/unit/aws_reel_service_test.dart`; `lib/services/aws/aws_reel_service.dart` | PASS |
| Reels like decrement | Save reel with `likeDelta: -1` | Request body contains decrement metadata and updated likes | `test/unit/aws_reel_service_test.dart`; `lib/services/aws/aws_reel_service.dart` | PASS |
| Reels polling refresh | `watchReels()` emits initial and polled feed | Stream emits refreshed reel values | `test/unit/aws_reel_service_test.dart`; `lib/services/aws/aws_reel_service.dart` | PASS |
| Notifications fetch | Fetch notifications by user id and role | Role-scoped NotificationModel list is returned | `test/unit/notification_service_test.dart`; `lib/services/aws/aws_notification_service.dart` | PASS |
| Notifications mark read | Mark notification as read by id | Read notification is returned and request body matches Lambda contract | `test/unit/notification_service_test.dart`; `lib/services/aws/aws_notification_service.dart` | PASS |
| Cook status routing | Approved cook route resolution | Approved cooks route to cook dashboard | `test/unit/cook_status_routing_test.dart`; `lib/core/router/app_router.dart` | PASS |
| Cook status routing | Pending verification route resolution | Pending cooks route to waiting approval | `test/unit/cook_status_routing_test.dart`; `lib/core/router/app_router.dart` | PASS |
| Cook status routing | Rejected/missing status route resolution | Rejected or missing status routes to verification upload | `test/unit/cook_status_routing_test.dart`; `lib/core/router/app_router.dart` | PASS |
| authLogin Lambda | Login checks password record across fallback tables | Correct user and cookStatus are returned | `backend/aws/authLogin.test.js`; `backend/aws/authLogin.js` | PASS |
| authRegister Lambda | Register normalizes email and creates session tokens | User item is stored with hashed password and stable tokens | `backend/aws/authRegister.test.js`; `backend/aws/authRegister.js` | PASS |
| authRegister Lambda duplicate validation | Register existing email | HTTP 409 duplicate email response | `backend/aws/authRegister.test.js`; `backend/aws/authRegister.js` | PASS |
| ordersCreate Lambda | Create order | Customer order counter is incremented and order starts pending review | `backend/aws/ordersStats.test.js`; `backend/aws/ordersCreate.js` | PASS |
| ordersUpdateStatus Lambda | Accept order | Accepted time and delivery deadline are stored | `backend/aws/ordersStats.test.js`; `backend/aws/ordersUpdateStatus.js` | PASS |
| ordersUpdateStatus Lambda | Reject direct delivered status | HTTP 400 instructs `confirm_received` flow | `backend/aws/ordersStats.test.js`; `backend/aws/ordersUpdateStatus.js` | PASS |
| ordersUpdateStatus Lambda | Confirm received | Delivered order creates payout and increments stats once | `backend/aws/ordersStats.test.js`; `backend/aws/ordersUpdateStatus.js` | PASS |
| ordersUpdateStatus Lambda | Confirm already delivered order | Cook totals are not incremented again | `backend/aws/ordersStats.test.js`; `backend/aws/ordersUpdateStatus.js` | PASS |
| ordersUpdateStatus Lambda | Rating before and after delivery | Rating is rejected before delivery and accepted after delivery | `backend/aws/ordersStats.test.js`; `backend/aws/ordersUpdateStatus.js` | PASS |
| pricingSuggest Lambda local fallback | Local provider pricing with valid ingredients | Deterministic fallback price and metadata are returned | `backend/aws/pricingSuggest.test.js`; `backend/aws/pricingSuggest.js` | PASS |
| pricingSuggest Lambda validation | Missing valid ingredients | HTTP 400 validation response | `backend/aws/pricingSuggest.test.js`; `backend/aws/pricingSuggest.js` | PASS |
| reelsSave Lambda | Save liked reel | Reel is stored and creator/liker counters update | `backend/aws/reelsSave.test.js`; `backend/aws/reelsSave.js` | PASS |
| reelsSave Lambda validation | Missing id or videoPath | HTTP 400 validation response | `backend/aws/reelsSave.test.js`; `backend/aws/reelsSave.js` | PASS |
| usersUploadUrl Lambda | Create verification document signed URL | Signed upload URL, file URL, key, and headers are returned | `backend/aws/usersUploadUrl.test.js`; `backend/aws/usersUploadUrl.js` | PASS |
| usersUploadUrl Lambda validation | Unsupported documentType | HTTP 400 validation response | `backend/aws/usersUploadUrl.test.js`; `backend/aws/usersUploadUrl.js` | PASS |
| notificationsList Lambda | List notifications by user id and role | Newest notifications are returned first | `backend/aws/notificationsList.test.js`; `backend/aws/notificationsList.js` | PASS |
| notificationsMarkRead Lambda | Mark notification read from JSON body | Updated read notification is returned | `backend/aws/notificationsMarkRead.test.js`; `backend/aws/notificationsMarkRead.js` | PASS |
| notificationsSave Lambda | Create notification | Notification item is saved and returned | `backend/aws/notificationsSave.test.js`; `backend/aws/notificationsSave.js` | PASS |

# Integration Testing Table

| Integration Test | Test Scenario | Expected Result | Tested Code / Reference | Actual Result |
|---|---|---|---|---|
| Flutter login flow | Flutter service -> AwsApiClient -> Auth Lambda-shaped response | User is authenticated and session is persisted | `test/integration/real_workflows_test.dart`; `AwsAuthService.login()` | PASS |
| Order lifecycle | create -> accept -> mark arrived -> confirm_received -> rate | Status sequence completes and rating is saved | `test/integration/real_workflows_test.dart`; `AwsOrderService` | PASS |
| Cook verification flow | upload URL -> upload simulation by signed URL contract -> cookStatus update | Both document URLs are requested and cookStatus becomes pending verification | `test/integration/real_workflows_test.dart`; `AwsAuthService.getUploadUrl()` / `updateCookSettings()` | PASS |
| AI pricing flow | Flutter pricing service -> pricing endpoint response parsing | Suggested price and metadata are parsed | `test/integration/real_workflows_test.dart`; `AwsPricingService.suggestPrice()` | PASS |
| Reels workflow | load reels -> like reel -> refresh feed | Refreshed feed shows incremented like state | `test/integration/real_workflows_test.dart`; `AwsReelService` | PASS |
| Notification workflow | create notification -> fetch -> mark read | Notification transitions from unread to read | `test/integration/real_workflows_test.dart`; `AwsNotificationService` | PASS |
| Live pricing API smoke | Flutter HTTP smoke test -> deployed pricing endpoint | Deployed pricing API returns HTTP 200 and valid pricing payload | `test/integration/pricing_api_smoke_test.dart`; AWS pricing endpoint | PASS |

# Academic Report Snippets

Authentication testing validated that `AwsAuthService.login()` authenticates through the AWS API client and stores the returned session locally using SharedPreferences.

Reference:
`lib/services/aws/aws_auth_service.dart`

Result:
PASS

Registration testing validated that `AwsAuthService.register()` sends the selected role to the auth endpoint and persists the returned customer or cook user.

Reference:
`lib/services/aws/aws_auth_service.dart`

Result:
PASS

Order service testing validated that `AwsOrderService.createOrder()` sends the real order payload to `/orders` and parses the returned `CustomerOrderModel`.

Reference:
`lib/services/aws/aws_order_service.dart`

Result:
PASS

Order lifecycle testing validated that the customer confirmation flow uses the `confirm_received` action before delivery is finalized.

Reference:
`lib/services/aws/aws_order_service.dart`

Result:
PASS

Rating validation testing confirmed that invalid pre-delivery rating operations are rejected and surfaced to Flutter as AWS API errors.

Reference:
`backend/aws/ordersUpdateStatus.js`

Result:
PASS

AI pricing testing validated both Groq response parsing in Flutter and deterministic local fallback pricing in the Lambda handler.

Reference:
`lib/services/backend/groq_pricing_service.dart`; `backend/aws/pricingSuggest.js`

Result:
PASS

Reels testing validated like increment/decrement metadata and polling refresh behavior through `AwsReelService`.

Reference:
`lib/services/aws/aws_reel_service.dart`

Result:
PASS

Notification testing validated fetching role-scoped notifications and marking notifications as read through the AWS notification service and Lambda handlers.

Reference:
`lib/services/aws/aws_notification_service.dart`; `backend/aws/notificationsMarkRead.js`

Result:
PASS

Kitchen verification testing validated signed upload URL handling and cook status routing for document-based verification.

Reference:
`lib/services/aws/aws_auth_service.dart`; `lib/core/router/app_router.dart`; `backend/aws/usersUploadUrl.js`

Result:
PASS

Backend authentication testing validated `authLogin.js` and `authRegister.js` business rules for password checks, duplicate email rejection, and normalized user creation.

Reference:
`backend/aws/authLogin.js`; `backend/aws/authRegister.js`

Result:
PASS

Backend order testing validated order creation, status transitions, delivery confirmation, payout creation, and rating rules in the Node.js Lambda handlers.

Reference:
`backend/aws/ordersCreate.js`; `backend/aws/ordersUpdateStatus.js`

Result:
PASS

Backend reels testing validated that saving a liked reel updates the reel table and user like counters while rejecting incomplete reel payloads.

Reference:
`backend/aws/reelsSave.js`

Result:
PASS

Backend upload testing validated that `usersUploadUrl.js` generates a signed verification document upload contract and rejects unsupported document types.

Reference:
`backend/aws/usersUploadUrl.js`

Result:
PASS

Executed verification commands:

```text
flutter analyze
flutter test
node --test backend\aws\*.test.js
```

Execution summary:

```text
Flutter analyze: PASS, No issues found
Flutter tests: PASS, 31 passed, 0 failed
Node tests: PASS, 23 passed, 0 failed
Integration tests: PASS, 7 passed, 0 failed
```
