# Firebase Setup Guide

## Quick Setup

Your app needs Firebase for **authentication only**. Follow these steps:

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `notebook-llm` (or your choice)
4. Disable Google Analytics (optional)
5. Click "Create project"

### 2. Add Android App

1. In Firebase Console, click "Add app" → Android icon
2. **Android package name**: `com.notebook.llm`
3. Click "Register app"
4. Download `google-services.json`
5. Place it in `android/app/google-services.json`

### 3. Get Firebase Configuration

In Firebase Console → Project Settings → General:

Copy these values to your `.env` file:

```env
# Firebase Configuration
FIREBASE_API_KEY=AIza...  # Web API Key
FIREBASE_PROJECT_ID=notebook-llm-xxxxx
FIREBASE_APP_ID=1:123456789:android:abcdef...
FIREBASE_MESSAGING_SENDER_ID=123456789
FIREBASE_AUTH_DOMAIN=notebook-llm-xxxxx.firebaseapp.com
FIREBASE_STORAGE_BUCKET=notebook-llm-xxxxx.appspot.com
```

### 4. Enable Authentication

1. In Firebase Console → Authentication
2. Click "Get started"
3. Enable "Email/Password" sign-in method
4. Click "Save"

### 5. Update android/app/build.gradle

Add at the bottom of the file:

```gradle
apply plugin: 'com.google.gms.google-services'
```

### 6. Update android/build.gradle

Add to dependencies:

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

## Testing

Run your app:

```bash
flutter clean
flutter pub get
flutter run
```

You should now be able to sign up and log in!

## Troubleshooting

### Error: "No Firebase App '[DEFAULT]' has been created"
- Make sure `.env` file has all Firebase credentials
- Restart the app after adding credentials

### Error: "google-services.json not found"
- Download from Firebase Console
- Place in `android/app/` folder

### Authentication not working
- Check Firebase Console → Authentication is enabled
- Verify Email/Password provider is enabled

## What Firebase is Used For

In your app, Firebase is **only** used for:
- ✅ User authentication (sign up, sign in, sign out)
- ✅ User session management

Everything else (data, media, functions) runs on **Neon PostgreSQL**!

## Optional: iOS Setup

If you want iOS support:

1. In Firebase Console, add iOS app
2. Bundle ID: `com.notebook.llm`
3. Download `GoogleService-Info.plist`
4. Place in `ios/Runner/`

## Security Rules

Firebase Authentication is secure by default. No additional rules needed since you're not using Firestore or Storage.

---

**Once configured, your app will have:**
- 🔐 Firebase Auth (authentication)
- 🗄️ Neon PostgreSQL (data + media + functions)
- 🤖 Gemini AI (AI features)
