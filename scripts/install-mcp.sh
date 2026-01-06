#!/bin/bash
# NotebookLLM MCP Server Installer for macOS/Linux
# Usage: curl -fsSL https://raw.githubusercontent.com/cmgzone/notebookllm/master/scripts/install-mcp.sh | bash

set -e

echo "📦 Installing NotebookLLM MCP Server..."

# Configuration - UPDATE THESE VALUES
GITHUB_REPO="cmgzone/notebookllm"
BACKEND_URL="https://notebookllm-ufj7.onrender.com"

# Get latest release
echo "🔍 Finding latest release..."
RELEASE_INFO=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" 2>/dev/null || echo "{}")
VERSION=$(echo "$RELEASE_INFO" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"mcp-v\([^"]*\)".*/\1/' || echo "1.0.0")
DOWNLOAD_URL=$(echo "$RELEASE_INFO" | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -1 | sed 's/.*"\(http[^"]*\)".*/\1/' || echo "")

if [ -z "$DOWNLOAD_URL" ]; then
    VERSION="1.0.0"
    DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/latest/download/notebookllm-mcp-$VERSION.zip"
fi

echo "📥 Downloading version $VERSION..."

# Create directory
MCP_DIR="$HOME/.notebookllm-mcp"
rm -rf "$MCP_DIR"
mkdir -p "$MCP_DIR"

# Download and extract
TEMP_ZIP="/tmp/notebookllm-mcp.zip"
curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_ZIP"
unzip -q "$TEMP_ZIP" -d "$MCP_DIR"
rm "$TEMP_ZIP"

# Install dependencies
echo "📥 Installing dependencies..."
cd "$MCP_DIR"
npm install --production --silent 2>/dev/null || npm install --production

# Copy AGENTS.md to coding agent directories if they exist
if [ -f "$MCP_DIR/AGENTS.md" ]; then
    # Kiro
    if [ -d "$HOME/.kiro/steering" ]; then
        echo "📋 Installing agent guide to Kiro..."
        cp "$MCP_DIR/AGENTS.md" "$HOME/.kiro/steering/notebookllm-mcp.md"
        echo "✅ Kiro: Agent guide installed"
    fi
    
    # Cursor
    if [ -d "$HOME/.cursor/prompts" ]; then
        echo "📋 Installing agent guide to Cursor..."
        cp "$MCP_DIR/AGENTS.md" "$HOME/.cursor/prompts/notebookllm-mcp.md"
        echo "✅ Cursor: Agent guide installed"
    fi
    
    # Windsurf (Codeium)
    if [ -d "$HOME/.codeium/windsurf/prompts" ]; then
        echo "📋 Installing agent guide to Windsurf..."
        cp "$MCP_DIR/AGENTS.md" "$HOME/.codeium/windsurf/prompts/notebookllm-mcp.md"
        echo "✅ Windsurf: Agent guide installed"
    fi
    
    # Cline (VSCode extension)
    if [ -d "$HOME/.vscode/extensions" ]; then
        CLINE_DIR=$(find "$HOME/.vscode/extensions" -maxdepth 1 -name "saoudrizwan.claude-dev-*" -type d 2>/dev/null | head -1)
        if [ -n "$CLINE_DIR" ] && [ -d "$CLINE_DIR/prompts" ]; then
            echo "📋 Installing agent guide to Cline..."
            cp "$MCP_DIR/AGENTS.md" "$CLINE_DIR/prompts/notebookllm-mcp.md"
            echo "✅ Cline: Agent guide installed"
        fi
    fi
    
    # Generic location for other agents
    echo "📋 Agent guide available at: $MCP_DIR/AGENTS.md"
fi

echo ""
echo "✅ NotebookLLM MCP Server v$VERSION installed to $MCP_DIR"
echo ""
echo "📝 Add this to your MCP config:"
echo ""
cat << EOF
{
  "mcpServers": {
    "notebookllm": {
      "command": "node",
      "args": ["$MCP_DIR/index.js"],
      "env": {
        "BACKEND_URL": "$BACKEND_URL",
        "CODING_AGENT_API_KEY": "YOUR_API_TOKEN_HERE"
      }
    }
  }
}
EOF
echo ""
echo "🔑 Get your API token from Settings → Agent Connections in the app"
echo ""
