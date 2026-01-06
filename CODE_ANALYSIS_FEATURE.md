# Code Analysis for GitHub Sources

When a coding agent adds a GitHub file as a source via the MCP server, the system now automatically analyzes the code to provide deep knowledge that improves fact-checking results.

## How It Works

1. **Automatic Analysis**: When `github_add_as_source` is called, the code is automatically analyzed in the background
2. **AI-Powered Insights**: Uses Gemini or OpenRouter (with automatic fallback) to generate comprehensive analysis
3. **Stored with Source**: Analysis is stored in the database alongside the source
4. **Enhanced Fact-Checking**: The analysis context is used to improve fact-checking accuracy for code sources

## AI Provider Support

The service supports both Gemini and OpenRouter with automatic fallback:

1. **Gemini** (primary): Uses `gemini-1.5-flash` model
2. **OpenRouter** (fallback): Uses `meta-llama/llama-3.3-70b-instruct` model
3. **Basic Analysis** (no AI): Falls back to static analysis if no AI is configured

Configure at least one of these environment variables:
- `GEMINI_API_KEY` - For Gemini AI
- `OPENROUTER_API_KEY` - For OpenRouter

## Analysis Results Include

### Overall Rating (1-10)
- 9-10: Excellent - Production-ready, well-documented, follows best practices
- 7-8: Good - Solid code with minor improvements possible
- 5-6: Average - Functional but needs refactoring
- 3-4: Below Average - Significant issues, needs work
- 1-2: Poor - Major problems, not recommended for production

### Quality Metrics (each 1-10)
- **Readability**: How easy is the code to read and understand
- **Maintainability**: How easy is it to modify and extend
- **Testability**: How easy is it to write tests for
- **Documentation**: Quality of comments and documentation
- **Error Handling**: Robustness of error handling

### Code Explanation
- **Summary**: What the code does overall
- **Purpose**: One-sentence description of main purpose
- **Key Components**: Functions, classes, interfaces with descriptions

### Architecture Analysis
- Detected architectural patterns (MVC, Repository, etc.)
- Design patterns used
- Separation of concerns notes

### Recommendations
- **Strengths**: What the code does well
- **Improvements**: Areas that could be better
- **Security Notes**: Any security concerns

### Metadata
- **analyzedBy**: Which AI provider was used (`gemini`, `openrouter`, or `basic`)

## MCP Tools

### `get_source_analysis`
Get the analysis for a source:
```javascript
const analysis = await get_source_analysis({ sourceId: "source-uuid" });
```

### `reanalyze_source`
Re-analyze a source (useful after updates):
```javascript
const analysis = await reanalyze_source({ sourceId: "source-uuid" });
```

## API Endpoints

### GET `/api/github/sources/:sourceId/analysis`
Returns the code analysis for a GitHub source.

### POST `/api/github/sources/:sourceId/reanalyze`
Triggers re-analysis of a GitHub source.

## Database Schema

New columns added to `sources` table:
- `code_analysis` (JSONB): Full analysis result
- `analysis_summary` (TEXT): Human-readable summary for fact-checking
- `analysis_rating` (SMALLINT): Quality rating 1-10
- `analyzed_at` (TIMESTAMPTZ): When analysis was performed

## Running the Migration

```bash
cd backend
npx tsx src/scripts/run-code-analysis-migration.ts
```

## Supported Languages

Analysis is performed for these code file types:
- JavaScript/TypeScript
- Python
- Dart
- Java/Kotlin
- Swift
- Go
- Rust
- C/C++
- C#
- Ruby
- PHP
- Scala
- Groovy
- Lua
- R
- Bash/PowerShell

Non-code files (JSON, YAML, Markdown, etc.) are skipped.

## Integration with Fact-Checking

The `FactCheckService` in Flutter now accepts optional code analysis context:

```dart
final results = await factCheckService.verifyContent(
  content,
  codeAnalysis: analysisResult,
);
```

This allows fact-checking to:
- Verify claims about code quality against the analysis rating
- Verify claims about what the code does against the summary
- Verify security claims against security notes
- Verify best practice claims against improvements
