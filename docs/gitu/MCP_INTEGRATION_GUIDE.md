# Gitu MCP Integration Guide

The Model Context Protocol (MCP) allows Gitu to securely access your data and tools. This guide explains the available MCP tools and how they integrate with your workflow.

## What is MCP?
MCP is a standard that enables AI models to interact with external data and systems safely. Gitu uses MCP to access your notebooks, verify code, and perform research.

## Available Tools

### Notebook Tools
These tools allow Gitu to interact with your NotebookLLM data.

- **`list_notebooks`**:
  - Lists all notebooks you have access to.
  - Usage: "Show me my notebooks", "List my recent projects".

- **`get_source`**:
  - Retrieves the content of a specific source within a notebook.
  - Usage: "Read the content of the 'Project Specs' source".

- **`search_sources`**:
  - Searches for text across all your notebook sources.
  - Usage: "Find references to 'authentication' in my notes".

### Code Tools
Tools for software development assistance.

- **`verify_code`**:
  - Checks code for syntax errors, security vulnerabilities, and best practices.
  - **Strict Mode**: Can be enabled for more rigorous checks.
  - Usage: "Verify this code snippet", "Check this function for bugs".

- **`review_code`** (Premium):
  - Performs a comprehensive AI code review with detailed feedback on performance, security, and readability.
  - Usage: "Review this file", "Do a security review of this module".

### GitHub Integration
(Requires GitHub account linking)
- **`github_search_code`**: Search for code in repositories.
- **`github_get_file`**: Read file contents from GitHub.
- **`github_create_issue`**: Open new issues directly from chat.

## Managing MCP Permissions
You can control which tools Gitu has access to in the app settings.
1. Go to **Settings > Integrations > MCP**.
2. Toggle individual tools on or off.
3. View usage logs to see what tools Gitu has used recently.
