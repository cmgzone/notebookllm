# Requirements Document

## Introduction

This feature bridges the GitHub Integration and Coding Agent Communication systems, enabling the notebook AI to access and discuss GitHub repository content, and allowing coding agents to have contextual conversations about specific code files through the NotebookLLM app.

## Glossary

- **Notebook_AI**: The AI assistant within the NotebookLLM app that helps users with their notebooks
- **Coding_Agent**: A third-party AI agent (Claude, Kiro, Cursor, etc.) that connects via MCP
- **GitHub_Source**: A source in a notebook that references a file from a GitHub repository
- **Code_Context**: The combination of file content, repository structure, and related files that provides context for AI discussions
- **MCP_GitHub_Tool**: A tool exposed via MCP that allows coding agents to interact with GitHub

## Requirements

### Requirement 1: GitHub Sources in Notebooks

**User Story:** As a user, I want to add GitHub files as sources to my notebooks, so that the notebook AI can reference and discuss the code.

#### Acceptance Criteria

1. WHEN a user selects "Add as Source" on a GitHub file, THE System SHALL create a GitHub_Source in the selected notebook
2. WHEN a GitHub_Source is created, THE System SHALL store the repository owner, repo name, file path, branch, and commit SHA
3. WHEN a GitHub_Source is viewed, THE System SHALL fetch the latest content from GitHub if the cached version is older than 1 hour
4. IF the GitHub file has been modified since the source was created, THEN THE System SHALL display a "File Updated" indicator
5. THE GitHub_Source SHALL display syntax-highlighted code with the file's language detected automatically

### Requirement 2: Notebook AI GitHub Context

**User Story:** As a user, I want the notebook AI to understand and discuss my GitHub sources, so that I can get help with my code.

#### Acceptance Criteria

1. WHEN a user asks a question in a notebook with GitHub_Sources, THE Notebook_AI SHALL include relevant source content in its context
2. WHEN discussing a GitHub_Source, THE Notebook_AI SHALL be able to reference specific line numbers and code sections
3. WHEN a user asks about code structure, THE Notebook_AI SHALL be able to fetch and analyze related files from the same repository
4. THE Notebook_AI SHALL maintain awareness of the repository structure when answering questions
5. WHEN the user asks to "analyze this repo", THE Notebook_AI SHALL use the github_analyze_repo MCP tool to provide comprehensive analysis

### Requirement 3: Coding Agent GitHub Access

**User Story:** As a coding agent, I want to access the user's connected GitHub repositories, so that I can help with their code.

#### Acceptance Criteria

1. WHEN a Coding_Agent calls github_list_repos, THE System SHALL return repositories accessible to the user's connected GitHub account
2. WHEN a Coding_Agent calls github_get_file, THE System SHALL return the file content with metadata (language, size, last modified)
3. WHEN a Coding_Agent calls github_search_code, THE System SHALL search across the user's accessible repositories
4. WHEN a Coding_Agent calls github_add_as_source, THE System SHALL create a GitHub_Source in the specified notebook
5. IF the user has not connected GitHub, THEN THE System SHALL return an error indicating GitHub connection is required

### Requirement 4: Agent-to-Notebook Code Discussion

**User Story:** As a user, I want coding agents to be able to discuss specific code files with me through the app, so that I can get help in context.

#### Acceptance Criteria

1. WHEN a Coding_Agent adds a GitHub file as a source, THE System SHALL enable the "Chat with Agent" feature on that source
2. WHEN a user sends a follow-up message about a GitHub_Source, THE System SHALL include the current file content in the webhook payload
3. WHEN a Coding_Agent responds about a GitHub_Source, THE System SHALL display code snippets with syntax highlighting
4. THE System SHALL support code diff display when the agent suggests modifications
5. WHEN the agent suggests a code change, THE System SHALL offer a "Create Issue" or "Create PR" action

### Requirement 5: Cross-System Context Sharing

**User Story:** As a user, I want my notebook AI and coding agents to share context about my code, so that I get consistent help.

#### Acceptance Criteria

1. WHEN a Coding_Agent saves code to an Agent_Notebook, THE Notebook_AI SHALL be able to reference that code in conversations
2. WHEN the Notebook_AI analyzes a GitHub repository, THE analysis SHALL be available to Coding_Agents via MCP
3. THE System SHALL maintain a unified code context that includes both GitHub_Sources and agent-saved code
4. WHEN switching between Notebook_AI and Coding_Agent conversations, THE System SHALL preserve relevant context

### Requirement 6: GitHub Actions from Chat

**User Story:** As a user, I want to perform GitHub actions directly from the chat interface, so that I can act on AI suggestions quickly.

#### Acceptance Criteria

1. WHEN the AI suggests creating an issue, THE System SHALL provide a one-click "Create Issue" button
2. WHEN the AI suggests a code fix, THE System SHALL provide a "Copy to Clipboard" action
3. WHEN viewing a GitHub_Source, THE System SHALL provide quick actions: "View on GitHub", "Copy Link", "Refresh"
4. THE System SHALL support creating GitHub issues with pre-filled title and body from AI suggestions

### Requirement 7: Security and Permissions

**User Story:** As a user, I want my GitHub access to be secure and scoped appropriately, so that my repositories are protected.

#### Acceptance Criteria

1. THE System SHALL only access repositories that the user has explicitly granted access to
2. WHEN a Coding_Agent requests GitHub access, THE System SHALL verify the agent has a valid session for that user
3. THE System SHALL log all GitHub API calls for audit purposes
4. THE System SHALL respect GitHub rate limits and display appropriate messages when limits are reached
5. IF a user revokes GitHub access, THEN THE System SHALL invalidate all cached tokens and notify connected agents

