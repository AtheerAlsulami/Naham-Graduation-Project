# Naham App
## Graduation Project
This project was developed as a Graduation Project for the Software Engineering program at Prince Sattam Bin Abdulaziz University.
### Team Members
- Atheer Habib Alsulami
- Munirah Abdulaziz Alfawzan
- Ghala Ali Alqahtani
---
## Project Overview
Naham is a Flutter mobile application that connects customers with home cooks. The application supports customer ordering, cook registration, kitchen verification, reels-style short videos, AI-assisted dish pricing, and admin management.
The project includes three main roles:
- Customer
- Cook
- Admin
---
## Main Features
### Customer
- Create an account and log in
- Browse dishes
- Place and track orders
- Watch reels-style food videos
- Rate dishes and cooks
### Cook
- Register and manage profile
- Upload verification documents
- Add and manage dishes
- Receive and manage orders
- Use AI-assisted pricing for dishes
- Upload reels for marketing
### Admin
- Manage users and cooks
- Review cook verification status
- Monitor orders
- Manage hygiene verification
- View reports and system data
---
## Technology Stack
### Frontend
- Flutter
- Dart
- Provider state management
- Go Router
- Shared Preferences
- Video Player
- Camera / Image Picker / File Picker
### Backend
- AWS API Gateway
- AWS Lambda
- Amazon DynamoDB
- Amazon S3
### Development Tools
- Android Studio
- Visual Studio Code
- GitHub
- Node.js
- PowerShell
---
## Project Structure
```text
lib/
  core/
    constants/
    router/
    theme/
  models/
  providers/
  screens/
    admin/
    auth/
    cook/
    customer/
  services/
    aws/
    backend/
    agora/
  widgets/
backend/
  aws/
test/
  integration/
  unit/
  widget/



Architecture Overview

The application is built using Flutter for the mobile interface and AWS services for backend operations.

The general flow is:

Flutter UI
-> Providers
-> Backend Services
-> AWS API Gateway
-> AWS Lambda
-> DynamoDB / S3

State management is handled using Provider.
Application routing is handled using Go Router.
User sessions are stored locally using Shared Preferences.



AI Pricing

The AI pricing feature helps cooks estimate dish prices based on dish information such as category, preparation time, ingredient costs, and profit value.

The project supports AI pricing using Groq and AWS Lambda, with a local fallback calculation if the remote AI service is unavailable.



Reels Feature

The reels feature allows cooks to upload short food videos for marketing. Customers can view reels, and the app supports video playback and caching.



Kitchen Verification

Cook verification is handled through document uploads and admin review. Verification files are uploaded using signed S3 upload URLs, and the cook status is updated in the system.



Installation and Run Instructions

Requirements

Before running the project, make sure the following tools are installed:

* Flutter SDK
* Dart SDK
* Android Studio or Visual Studio Code
* Android Emulator or a physical Android device
* Node.js

Steps to Run

1. Clone the repository:

git clone REPOSITORY_URL

2. Open the project in Android Studio or Visual Studio Code.
3. Install Flutter dependencies:

flutter pub get

4. Run the application:

flutter run

Make sure an emulator or Android device is connected before running the app.



Testing

To analyze the Flutter code:

flutter analyze

To run Flutter tests:

flutter test

```
