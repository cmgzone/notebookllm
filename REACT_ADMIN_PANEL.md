# React Admin Panel Setup Guide

## ✅ React Admin Panel Now Available!

I've created a beautiful, modern React-based admin panel for managing AI models with full CRUD operations and an easy-to-use interface.

## Access the Admin Panel

**URL**: `http://localhost:3000/admin/admin-ai-models.html`

(Or replace `localhost:3000` with your backend URL)

## Features

### 🎨 Beautiful Modern UI
- **Gradient header** with premium feel
- **Card-based layout** for each model
- **Color-coded badges** for status (Active/Inactive, Premium)
- **Responsive design** works on mobile and desktop
- **Smooth animations** and transitions

### ✨ Full CRUD Operations
- ✅ **Create** new AI models
- ✅ **Read** and view all models
- ✅ **Update** existing models
- ✅ **Delete** models with confirmation

### 🎯 Context Window Management
- **Input field** for manual entry
- **Quick preset buttons** for common sizes:
  - 128K - For Nano, standard models
  - 200K - For Claude 3.x
  - 1M - For Gemini Flash
  - 2M - For Gemini Pro
- **Auto-detect hint** - Leave at 0 for automatic detection

### 📋 All Fields Supported
- **Display Name** - User-friendly name
- **Model ID** - API identifier (e.g., `gemini-2.0-flash-exp`)
- **Provider** - Dropdown (Gemini, OpenRouter, OpenAI, Anthropic)
- **Context Window** - With quick presets
- **Input/Output Costs** - Per 1K tokens
- **Description** - Optional notes
- **Premium** - Checkbox for paid models
- **Active** - Toggle visibility in selector

## Example: Adding Nano Mini

1. **Open** `http://localhost:3000/admin/admin-ai-models.html`
2. **Click** "+ Add Model" button
3. **Fill in**:
   ```
   Display Name: Nano Mini
   Model ID: google/gemini-nano-mini
   Provider: gemini (or openrouter)
   Context Window: 128000 (or click "128K" button)
   Input Cost: 0
   Output Cost: 0
   Premium: ☐ (unchecked)
   Active: ☑ (checked)
   ```
4. **Click** "💾 Save Model"
5. **Done!** The model appears instantly

## Backend Setup

The backend is already configured to:
- ✅ Serve admin panel at `/admin/*` route
- ✅ Handle AI models API at `/api/ai-models`
- ✅ Support all CRUD operations
- ✅ Validate and store context window values

## Security Note

⚠️ **Production Warning**: This admin panel has no authentication!

For production, you should:
1. Add authentication middleware
2. Restrict access to admin users only
3. Use HTTPS
4. Add rate limiting

## Alternative: Flutter Admin Panel

If you prefer the Flutter app admin panel:
1. Open the Flutter app
2. Navigate to Settings → Admin → AI Models Manager
3. The context window field has also been added there

## Troubleshooting

### Panel not loading?
- Check backend is running on port 3000
- Verify `public` folder exists in backend directory
- Check browser console for errors

### Can't save models?
- Verify API route `/api/ai-models` is accessible
- Check database connection
- View backend logs for errors

### Context window not saved?
- Make sure you're entering a number (e.g., 128000)
- Use preset buttons for guaranteed correct values
- Check if value appears in the model details after saving

## Quick Access URLs

- **Admin Panel**: `http://localhost:3000/admin/admin-ai-models.html`
- **Backend Health**: `http://localhost:3000/health`
- **AI Models API**: `http://localhost:3000/api/ai-models`

## Technologies Used

- **React 18** - via CDN (no build step needed!)
- **Babel Standalone** - For JSX transformation
- **Pure CSS** - No frameworks, fully custom
- **Fetch API** - For backend communication

## Benefits Over Flutter Admin

- ✅ **No app needed** - Works in any browser
- ✅ **Instant updates** - Refresh to reload
- ✅ **Easy to customize** - Just edit HTML/CSS/JS
- ✅ **Shareable** - Send URL to team members
- ✅ **Multi-platform** - Works everywhere

Enjoy your new admin panel! 🎉
