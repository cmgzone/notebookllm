# Voice Mode Guide

## Overview
Voice Mode is an AI-powered voice assistant that lets you interact with your Notebook LLM app hands-free. You can have conversations, create notes, search your content, and manage your notebooks using just your voice.

## How to Access
1. Open the app and go to the home screen
2. Tap the floating "Voice Mode" button (microphone icon) at the bottom right
3. Grant microphone permissions when prompted
4. Start speaking!

## What You Can Do

### 📝 Create Notes
Just speak naturally and the AI will save your notes:

**Examples:**
- "Create a note about today's meeting"
- "Save this: Remember to buy groceries tomorrow"
- "Write a note called Project Ideas with the content: Build a mobile app for tracking habits"
- "Take a note: The client wants the design by Friday"

### 🔍 Search Your Content
Find information in your sources:

**Examples:**
- "Search my sources for Python tutorials"
- "Find notes about machine learning"
- "What do I have about project deadlines?"
- "Search for information on React"

### 📊 View Your Data
Get information about your notebooks and sources:

**Examples:**
- "How many sources do I have?"
- "List my notebooks"
- "Show me my sources"
- "What notebooks do I have?"

### 📚 Create Notebooks
Organize your content with new notebooks:

**Examples:**
- "Create a notebook called Work Projects"
- "Make a new notebook for Study Notes"
- "Create a notebook named Personal Ideas"

### 📋 Get Summaries
Get quick summaries of your content:

**Examples:**
- "Summarize my recent sources"
- "Give me a summary of my notes"
- "What's in my sources?"

### 🎨 Generate Images
Request AI-generated images via voice using Gemini Imagen:

**Examples:**
- "Generate an image of a sunset over mountains"
- "Create a picture of a futuristic city"
- "Draw a cute robot"
- "Make an image of a cozy coffee shop"

*Powered by Gemini Imagen 3 - High-quality AI image generation*

### 💬 General Conversation
Ask questions and have natural conversations:

**Examples:**
- "What's the weather like?"
- "Tell me a joke"
- "How do I learn Python?"
- "Explain quantum computing"

## Visual States

### 🎤 Idle (Blue Circle)
- Ready to listen
- Tap the microphone to start speaking

### 🔴 Listening (Red Circle with Animation)
- Actively recording your voice
- Tap to stop recording
- Speak clearly and naturally

### ⏳ Processing (Loading Spinner)
- AI is thinking and processing your request
- May be performing actions like saving notes

### 🔊 Speaking (Purple Circle with Shimmer)
- AI is responding with voice
- Tap to stop the response

## Tips for Best Results

1. **Speak Clearly**: Speak at a normal pace in a quiet environment
2. **Be Specific**: When creating notes, mention the title and content clearly
3. **Natural Language**: You don't need special commands - just speak naturally
4. **Wait for Response**: Let the AI finish speaking before your next request
5. **Context Aware**: The AI remembers the last 10 exchanges in your conversation

## Technical Details

### Powered By:
- **Speech Recognition**: Flutter speech_to_text
- **AI Processing**: Google Gemini AI
- **Voice Synthesis**: ElevenLabs TTS
- **Intent Detection**: Smart AI-powered action detection

### Actions Performed:
- ✅ Create and save text notes to sources
- ✅ Search through all your sources
- ✅ List notebooks and sources
- ✅ Create new notebooks
- ✅ Generate summaries
- ✅ Natural conversation

## Privacy & Permissions

- **Microphone**: Required for voice input
- **Internet**: Required for AI processing and voice synthesis
- **Data**: Your voice is processed by Google (speech recognition) and ElevenLabs (voice synthesis)
- **Storage**: Notes and notebooks are saved to your Supabase database

## Troubleshooting

**Voice not recognized?**
- Check microphone permissions
- Ensure you're in a quiet environment
- Speak clearly and at normal volume

**AI not responding?**
- Check internet connection
- Verify Gemini API key is configured
- Check ElevenLabs API key is configured

**Actions not working?**
- Ensure you're logged in
- Check Supabase connection
- Try being more specific with your request

## Example Workflow

1. **Start Voice Mode**: Tap the microphone button
2. **Create a Note**: "Create a note called Meeting Notes with the content: Discussed Q4 goals and budget planning"
3. **AI Confirms**: "I've saved your note titled Meeting Notes to your sources"
4. **Search Later**: "Search my sources for budget"
5. **AI Responds**: "I found 1 source. The top match is: Meeting Notes"

## Future Enhancements

Coming soon:
- Add tags to notes via voice
- Edit existing notes
- Delete sources
- Query specific notebooks
- Web search integration
- Deep research mode
- Export and share via voice

---

**Enjoy your hands-free notebook experience!** 🎤✨
