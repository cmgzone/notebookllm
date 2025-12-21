# 🎉 Context Engineering AI Agent - Quick Start Guide

## ✅ What We've Built

A powerful **Context Engineering AI Agent** that:
- Analyzes user behavior patterns and learning styles
- Identifies interests with confidence scoring
- Builds knowledge graphs of user domains
- Performs deep web searches for enrichment
- Predicts future interests
- Generates personalized recommendations
- Creates comprehensive AI-powered user profiles

## 🚀 How to Use

### 1. Access the Feature

Click the **brain icon (🧠 Psychology)** in the top app bar on the home screen.

Or navigate to: `/context-profile`

### 2. Build Your Profile

1. Click the **"Build Profile"** button
2. Wait 30-60 seconds while the AI:
   - Analyzes your notebooks and sources
   - Identifies behavior patterns
   - Extracts interest themes
   - Performs deep research (optional)
   - Predicts future interests
   - Generates personalized recommendations

3. Explore your profile with beautiful visual cards showing:
   - **Behavior Profile**: Engagement, learning style, preferences
   - **Interest Themes**: Topics you're passionate about
   - **Knowledge Graph**: Your expertise map
   - **Temporal Patterns**: When you're most active
   - **Predictions**: What you'll be interested in next
   - **Recommendations**: Personalized content suggestions
   - **Summary**: Comprehensive AI-generated overview

### 3. Rebuild Anytime

Click **"Rebuild Profile"** to update with latest activities.

## 🎨 Visual Features

- **Dark theme** with vibrant color-coded cards
- **Progress bars** showing confidence levels
- **Interactive chips** for tags and keywords
- **Real-time progress** during profile building
- **Markdown rendering** for rich summaries

## 📊 What Gets Analyzed

- **Notebooks**: Creation patterns, topics, descriptions
- **Sources**: Content, types, timestamps
- **Future**: Chat history, voice interactions, searches

## 🔮 AI Capabilities

### Behavior Analysis
- Engagement level (low/medium/high)
- Learning style (visual/auditory/kinesthetic/reading)
- Complexity preference (simple/moderate/advanced)
- Primary behaviors and interaction patterns

### Interest Extraction
- Topic identification
- Confidence scoring (0-100%)
- Category classification
- Depth assessment (beginner/intermediate/advanced)
- Related keywords

### Knowledge Mapping
- Domain nodes and connections
- Central themes identification
- Knowledge gap detection
- Skill relationship mapping

### Deep Search (Optional)
- Web searches for top 3 interests
- Page content extraction
- Related concept discovery
- External knowledge enrichment

### Temporal Intelligence
- Peak activity hours
- Peak activity days
- Activity trends (increasing/stable/decreasing)
- Average session duration

### Predictive AI
- Future interest forecasting
- Reasoning explanation
- Confidence scoring
- Time frame estimation (short/medium/long-term)

## 🛠️ Technical Details

### Files Created
1. `lib/core/ai/context_engineering_service.dart` - Core service
2. `lib/features/chat/context_profile_screen.dart` - UI  
3. `lib/core/router.dart` - Route added
4. `lib/features/home/home_screen.dart` - Navigation button

### API Requirements
- **Gemini** or **OpenRouter** API key (required)
- **Serper** API key (optional, for deep search)

### Data Storage
- Profiles saved to SharedPreferences
- Automatic save after generation
- Loads on screen open

### Performance
- Profile build: 30-60 seconds
- With deep search: +20-30 seconds
- Cached load: <1 second

## 💡 Use Cases

1. **Onboarding**: Understand new users quickly
2. **Content Recommendations**: Suggest relevant notebooks
3. **Learning Optimization**: Match content to learning style
4. **Engagement**: Send notifications at peak times
5. **Discovery**: Fill knowledge gaps with suggestions

## 🎯 Next Steps

1. Try building your first profile
2. Explore the different insight cards
3. Use recommendations to discover new content
4. Rebuild periodically to track changes

## 🔧 Customization

You can customize:
- Deep search toggle (on/off)
- Number of interests searched (currently 3)
- AI prompts for analysis
- Visual themes and colors
- Recommendation count

## 📝 Example Profile Output

```
Behavior: High engagement, visual learner, advanced complexity
Interests: Machine Learning (95%), Data Science (87%)
Knowledge Gaps: Cloud Architecture, DevOps
Predictions: Quantum Computing, Advanced Statistics
Peak Hours: 9AM, 2PM, 8PM
Peak Days: Mon, Wed, Fri
```

## ⚠️ Notes

- Requires existing activity (notebooks/sources) to analyze
- More data = better insights
- Deep search requires internet connection
- Profiles are user-specific and private
- Can be rebuilt anytime with fresh data

---

**Enjoy hyper-personalized AI experiences!** 🚀
