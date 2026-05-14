# Naham Technical Documentation

This document describes the implemented technical architecture of the Naham Flutter + AWS project. It is based on the current project structure and code paths, not on planned or assumed functionality.

## 1. System Overview

Naham is a multi-role Flutter application backed by AWS API Gateway, AWS Lambda, DynamoDB, and S3. The active roles are Customer, Cook, and Admin.

The application is a production-like prototype. It contains real backend integrations and business logic, but some production-grade components are not currently implemented, including Cognito-based authentication, JWT authorization, and real payment gateway processing.

## 2. Layered Architecture

| Layer | Responsibility | Representative Files |
| --- | --- | --- |
| Presentation Layer | UI screens and user workflows | `lib/screens/customer/*`, `lib/screens/cook/*`, `lib/screens/admin/*`, `lib/screens/auth/*` |
| State Management | UI state, loading states, authenticated user binding | `lib/providers/auth_provider.dart`, `lib/providers/orders_provider.dart`, `lib/providers/dish_provider.dart` |
| Backend Abstraction | App-facing service interface | `lib/services/backend/backend_auth_service.dart`, `lib/services/backend/backend_order_service.dart`, `lib/services/backend/backend_pricing_service.dart` |
| AWS Layer | API Gateway HTTP calls and AWS endpoint mapping | `lib/services/aws/aws_api_client.dart`, `lib/services/aws/aws_auth_service.dart`, `lib/services/aws/aws_order_service.dart` |
| Data Models | Data conversion and typed app state | `lib/models/user_model.dart`, `lib/models/dish_model.dart`, `lib/models/customer_order_model.dart`, `lib/models/cook_reel_model.dart` |
| Backend Infrastructure | Lambda handlers and AWS business logic | `backend/aws/*.js` |

## 3. API Flow

Standard request flow:

```text
Flutter UI
-> Provider
-> Backend Service
-> AWS Service
-> AwsApiClient
-> API Gateway
-> AWS Lambda
-> DynamoDB or S3
-> JSON response
-> Model parsing
-> Provider state update
-> UI rebuild
```

Example order flow:

```text
CheckoutScreen
-> OrdersProvider.placeOrderFromCart
-> BackendOrderService.createOrder
-> AwsOrderService.createOrder
-> POST /orders
-> ordersCreate.js
-> DynamoDB orders table
```

## 4. Authentication Flow

### Implementation

Authentication is custom and Lambda-based.

Core files:

- `lib/providers/auth_provider.dart`
- `lib/services/backend/backend_auth_service.dart`
- `lib/services/aws/aws_auth_service.dart`
- `backend/aws/authRegister.js`
- `backend/aws/authLogin.js`
- `backend/aws/authGoogleSignin.js`

### Email And Password Flow

```text
LoginScreen/RegisterScreen
-> AuthProvider
-> BackendAuthService
-> AwsAuthService
-> /auth/login or /auth/register
-> Lambda
-> DynamoDB users table
-> user payload + custom tokens
-> SharedPreferences
```

The backend stores password hashes and checks login attempts by hashing the submitted password and comparing it with the stored `passwordHash`.

### Google Sign-In Flow

Flutter uses `google_sign_in` to obtain Google identity data and sends it to:

```text
POST /auth/google-signin
```

The backend maps the Google account to a Naham user record.

### Session Persistence

`AwsAuthService` saves user JSON and token fields in `SharedPreferences`. On startup, `SplashScreen` calls `AuthProvider.checkAuthStatus()`. For cooks, it also refreshes the current user to obtain the latest `cookStatus`.

### Important Limitation

There is no active Amazon Cognito integration or strong JWT validation in the current request flow.

## 5. Role And Route Control

Main route control is handled in:

- `lib/core/router/app_router.dart`

Cook route behavior depends on `UserModel.cookStatus`:

| cookStatus | Route |
| --- | --- |
| `approved` | `/cook/dashboard` |
| `pending_verification` | `/cook/waiting-approval` |
| any other value | `/cook/verification-upload` |

This prevents non-approved cooks from directly accessing the cook dashboard.

## 6. Order Lifecycle

Core files:

- `lib/providers/orders_provider.dart`
- `lib/services/aws/aws_order_service.dart`
- `backend/aws/ordersCreate.js`
- `backend/aws/ordersList.js`
- `backend/aws/ordersUpdateStatus.js`

### Create Order

Orders are created from cart items and include customer, cook, item, address, price, and payment metadata.

Important fields:

- `customerId`
- `cookId`
- `items`
- `subtotal`
- `deliveryFee`
- `totalAmount`
- `cookEarnings`
- `payment`
- `status`
- `approvalExpiresAt`

Payment is metadata only. No real payment provider is integrated in the current project.

### Status Actions

`ordersUpdateStatus.js` centralizes lifecycle updates through explicit actions:

| Action | Purpose |
| --- | --- |
| `accept` | Cook accepts a pending order |
| `reject` | Cook rejects a pending order |
| `cancel` | Cancels an allowed active/preparing order |
| `mark_out_for_delivery` | Marks order as sent out |
| `mark_arrived` | Marks arrival and waits for customer confirmation |
| `confirm_received` | Customer confirms receipt and order becomes delivered |
| `nudge_late` | Customer sends late-order reminder |
| `report_issue` | Customer reports an issue |
| `request_replacement` | Customer requests replacement after issue report |
| `approve_replacement` | Cook approves replacement |
| `rate` | Customer rates delivered order |

Direct writes to `delivered` are rejected. Delivery must go through `confirm_received`.

### Side Effects

The order backend can update:

- Cook statistics
- Dish order statistics
- Payout records
- Notifications
- Rating statistics

## 7. Kitchen Verification Flow

Core files:

- `lib/screens/cook/cook_verification_upload_screen.dart`
- `lib/providers/auth_provider.dart`
- `lib/services/aws/aws_auth_service.dart`
- `backend/aws/usersUploadUrl.js`
- `backend/aws/usersUpdateStatus.js`
- `test/integration/test_cook_verification_flow.ps1`

### Flow

```text
Cook selects ID and health documents
-> AuthProvider.submitCookVerification
-> POST /users/upload-url for ID document
-> POST /users/upload-url for health document
-> Lambda creates signed S3 upload URLs
-> Flutter uploads documents directly to S3
-> Flutter updates user with document URLs and cookStatus
-> Admin can approve or reject through user status update flow
```

### Stored Fields

| Field | Meaning |
| --- | --- |
| `cookStatus` | Verification state |
| `verificationIdUrl` | S3/public URL for identity document |
| `verificationHealthUrl` | S3/public URL for health document |

Allowed cook statuses include:

- `approved`
- `pending_verification`
- `frozen`
- `blocked`
- `rejected`

## 8. Reels Upload And Playback Flow

Core files:

- `lib/services/reel_service.dart`
- `lib/services/aws/aws_reel_service.dart`
- `lib/widgets/reel_video_surface.dart`
- `lib/screens/customer/customer_reels_screen.dart`
- `lib/screens/cook/cook_reels_screen.dart`
- `backend/aws/reelsUploadUrl.js`
- `backend/aws/reelsSave.js`
- `backend/aws/reelsList.js`

### Upload Flow

```text
Cook reel UI
-> ReelService.uploadVideoFile
-> AwsReelService.uploadVideoFile
-> POST /reels/upload-url
-> reelsUploadUrl.js
-> signed S3 PUT URL
-> Flutter uploads video file
-> POST /reels saves reel metadata
-> DynamoDB reels table
```

### Playback Flow

`ReelVideoSurface` loads remote videos through `flutter_cache_manager`. If caching succeeds, the cached local file is played using `VideoPlayerController.file`. If caching fails, the widget falls back to network playback.

### Feed Updates

`AwsReelService.watchReels()` polls every 5 seconds. WebSocket push updates are not implemented.

### Interactions

Implemented interactions include:

- Likes
- Comments
- Bookmarks
- Follows/unfollows
- Share UI behavior

Likes can update reel counts and user `likedReelsCount`. Follows are handled through the follows backend.

## 9. Pricing AI Flow

Core files:

- `lib/screens/cook/cook_ai_pricing_screen.dart`
- `lib/services/backend/backend_pricing_service.dart`
- `lib/services/backend/groq_pricing_service.dart`
- `lib/services/aws/aws_pricing_service.dart`
- `backend/aws/pricingSuggest.js`

### Inputs

| Input | Meaning |
| --- | --- |
| `categoryId` | Dish category |
| `preparationMinutes` | Estimated preparation time |
| `ingredients` | Ingredient weight and cost data |
| `profitMode` | Fixed or percentage profit mode |
| `profitValue` | Profit amount or percentage |
| `currentPrice` | Optional current dish price |

### Execution Paths

| Path | Description |
| --- | --- |
| Direct Groq | Flutter calls Groq-compatible chat completions through `GroqPricingService` |
| AWS Lambda | Flutter calls `/pricing/suggest`, then `pricingSuggest.js` routes to OpenAI, Groq, Gemini, or local logic |
| Local fallback | Calculation-based fallback uses ingredient cost, packaging, operation cost, and profit |

### Important Limitation

This is AI-assisted pricing. It should not be documented as a complete AI recommendation or personalization engine.

## 10. Ranking-Based Recommendations

The current recommendation behavior is ranking-based.

Signals used by the project:

- `currentMonthOrders`
- `totalOrders`
- cook ratings
- reel likes/popularity
- follow and liked reel counters

Examples:

- `CookProvider` sorts cooks by `currentMonthOrders`.
- `dishesList.js` can sort dishes by current-month order counts or total orders.
- `usersList.js` computes cook order totals and reel-like totals from orders and reels.

There is no full AI recommendation engine in the current codebase.

## 11. Database Documentation

The project uses DynamoDB. Table names are provided by Lambda environment variables, with fallback names in some handlers.

### users / naham_users

Representative model:

- `lib/models/user_model.dart`

Important fields:

| Field | Purpose |
| --- | --- |
| `id` | Stable user identifier |
| `name` | User name |
| `displayName` | Optional display name |
| `email` | Login/contact email |
| `phone` | Phone number |
| `role` | `customer`, `cook`, or `admin` |
| `profileImageUrl` | Profile media URL |
| `address` | User address |
| `cookStatus` | Cook approval state |
| `rating` | Cook rating |
| `totalOrders` | Cook lifetime order count |
| `monthlyOrderCounts` | Per-month order counts |
| `currentMonthOrders` | Current month order count |
| `followersCount` | Cook follower count |
| `reelLikesCount` | Likes received on cook reels |
| `ordersPlacedCount` | Customer order count |
| `likedReelsCount` | Customer liked reels count |
| `followingCooksCount` | Customer followed cooks count |
| `verificationIdUrl` | ID document URL |
| `verificationHealthUrl` | Health document URL |

Relationships:

- A cook user owns dishes through `DishModel.cookId`.
- A customer user owns orders through `CustomerOrderModel.customerId`.
- A cook user receives orders through `CustomerOrderModel.cookId`.
- Cook verification documents are stored in S3 and referenced from the user record.

### dishes

Representative model:

- `lib/models/dish_model.dart`

Important fields:

| Field | Purpose |
| --- | --- |
| `id` | Dish identifier |
| `cookId` | Owning cook ID |
| `cookName` | Cook display name at time of save |
| `name` | Dish name |
| `description` | Dish description |
| `price` | Dish price |
| `imageUrl` | Dish image URL |
| `rating` | Display rating |
| `reviewsCount` | Review count |
| `currentMonthOrders` | Computed or stored monthly demand |
| `totalOrders` | Computed or stored total demand |
| `categoryId` | Food category |
| `ingredients` | Ingredient labels |
| `isAvailable` | Availability flag |
| `preparationTimeMin` | Minimum preparation time |
| `preparationTimeMax` | Maximum preparation time |
| `createdAt` | Creation timestamp |

Relationships:

- Dish belongs to a cook.
- Order items reference dishes by `dishId`.
- Dish image files are stored in S3.

### orders

Representative model:

- `lib/models/customer_order_model.dart`

Important fields:

| Field | Purpose |
| --- | --- |
| `id` | Order identifier |
| `displayId` | Human-readable order ID |
| `customerId` | Customer owner |
| `customerName` | Customer display name |
| `cookId` | Cook assigned to the order |
| `cookName` | Cook display name |
| `status` | Current lifecycle status |
| `itemsJson` | JSON array of order items in DynamoDB |
| `deliveryAddressJson` | JSON delivery address |
| `paymentJson` | Payment metadata, not gateway transaction proof |
| `trackingJson` | Tracking metadata |
| `subtotal` | Items subtotal |
| `deliveryFee` | Delivery charge |
| `totalAmount` | Total amount |
| `cookEarnings` | Cook payout basis |
| `prepEstimateMinutes` | Preparation estimate |
| `approvalExpiresAt` | Cook approval timeout timestamp |
| `deliveryDueAt` | Expected delivery deadline |
| `statusHistory` | Status history JSON |
| `replacementHistory` | Replacement workflow JSON |
| `payoutId` | Linked payout record ID |
| `rating` | Customer cook rating |
| `cookRating` | Cook-specific rating |
| `serviceRating` | Service rating |
| `reviewComment` | Review text |

Relationships:

- Orders belong to customers.
- Orders are assigned to cooks.
- Orders reference one or more dish items.
- Delivered orders update cook/dish statistics and may create payout records.

### reels

Representative model:

- `lib/models/cook_reel_model.dart`

Important fields:

| Field | Purpose |
| --- | --- |
| `id` | Reel identifier |
| `creatorId` | Cook/user who created the reel |
| `creatorName` | Creator display name |
| `creatorImageUrl` | Creator image URL |
| `title` | Reel title |
| `description` | Reel description |
| `imageUrl` | Optional image/thumbnail |
| `videoPath` | Reel video URL/path |
| `audioLabel` | Audio display label |
| `likes` | Like count |
| `comments` | Comment count |
| `shares` | Share count |
| `isFollowing` | UI state for following creator |
| `isLiked` | UI state for like |
| `isBookmarked` | UI state for bookmark |
| `isDraft` | Draft state |
| `commentItems` | Stored comment data |
| `createdAt` | Creation timestamp |

Relationships:

- Reels belong to cooks/users through `creatorId`.
- Reel video files are stored in S3.
- Reel likes can contribute to cook popularity statistics.

## 12. Testing Structure

### Flutter Test Organization

Location:

```text
test/helpers/
test/integration/
test/unit/
test/widget/
```

Examples:

| File | Purpose |
| --- | --- |
| `test/unit/groq_pricing_service_test.dart` | Tests Groq pricing request and response parsing |
| `test/unit/notification_service_test.dart` | Notification service behavior |
| `test/unit/auth_error_message_test.dart` | Auth error message formatting |
| `test/widget/widget_test.dart` | Flutter app widget smoke test |
| `test/integration/pricing_api_smoke_test.dart` | Smoke test for deployed pricing API |

### Backend Lambda Tests

Location:

```text
backend/aws/*.test.js
```

Examples:

| File | Purpose |
| --- | --- |
| `backend/aws/authLogin.test.js` | Auth Lambda behavior |
| `backend/aws/follows.test.js` | Follow/unfollow relationship and counters |
| `backend/aws/notificationsList.test.js` | Notification listing |
| `backend/aws/notificationsMarkRead.test.js` | Notification read status |
| `backend/aws/notificationsSave.test.js` | Notification save |
| `backend/aws/ordersStats.test.js` | Order lifecycle and statistics behavior |
| `backend/aws/dishesListStats.test.js` | Dish statistics derived from orders |

### PowerShell Smoke Tests

Location:

```text
test/integration/*.ps1
```

Important scripts:

| File | Purpose |
| --- | --- |
| `test/integration/test_cook_verification_flow.ps1` | End-to-end cook verification upload/status/route smoke test |
| `test/integration/test_pricing.ps1` | Pricing API test |
| `test/integration/test_pricing_local_lambda.ps1` | Local pricing Lambda-oriented test |
| `test/integration/test_groq_direct.ps1` | Direct Groq pricing test |

## 13. Security Analysis

### Implemented

- S3 signed URLs for direct uploads.
- Cook route protection based on backend `cookStatus`.
- Backend validation for allowed account and cook statuses.
- Backend validation for order lifecycle actions.
- Direct delivered status writes are blocked in favor of customer confirmation.

### Current Risks

- A Groq API key is currently present in Flutter configuration.
- Custom authentication is weaker than a managed identity provider.
- No strong JWT verification was found in active Lambda request handling.
- Development setup references broad AWS IAM permissions.
- Admin operations should be reviewed for explicit authorization enforcement before production.

## 14. Performance Analysis

Implemented performance behaviors:

- Remote reels are cached locally before video playback when possible.
- Provider caching avoids repeated cook/dish fetches.
- Reels polling interval is fixed at 5 seconds.
- Backend list APIs use query limits and Lambda scan constraints.
- Media upload goes directly from Flutter to S3 through signed URLs.
- Async provider methods update UI state after backend calls complete.

Tradeoffs:

- Polling is simpler than WebSockets but can increase API calls and does not provide instant push updates.
- DynamoDB scan-based listing is acceptable for prototype scale but should be reviewed for production-scale access patterns and indexes.

## 15. Non-Implemented Or Partial Areas

| Area | Current Status |
| --- | --- |
| Cognito authentication | Not implemented |
| Firebase backend | Not used |
| AWS Amplify | Not used |
| SES/SNS messaging | Not used |
| Real payment gateway | Not implemented; payment is metadata only |
| AI personalization engine | Not implemented; recommendations are ranking-based |
| WebSocket real-time updates | Not implemented; reels use polling |
| Production-grade authorization | Partial; route/status validation exists, but JWT enforcement was not found |
