"use client";

import React, { useState } from "react";
import {
  BrainCircuit,
  Code,
  Terminal,
  Key,
  Shield,
  Copy,
  Check,
  ChevronDown,
  ChevronRight,
  Zap,
  Settings,
  FileCode,
  ArrowRight,
  ExternalLink,
  BookOpen,
  Cpu,
  Lock,
  RefreshCw
} from "lucide-react";
import Link from "next/link";
import { motion, AnimatePresence } from "framer-motion";

export default function DocsPage() {
  return (
    <div className="min-h-screen bg-neutral-950 text-white">
      <DocsNav />
      <div className="container mx-auto px-6 py-12">
        <div className="grid lg:grid-cols-[280px_1fr] gap-12">
          <Sidebar />
          <main className="max-w-4xl">
            <HeroSection />
            <QuickStartSection />
            <AuthenticationSection />
            <ToolsSection />
            <ConfigurationSection />
            <TokenManagementSection />
            <ArchitectureSection />
          </main>
        </div>
      </div>
      <Footer />
    </div>
  );
}

function DocsNav() {
  return (
    <nav className="sticky top-0 z-50 border-b border-white/5 bg-neutral-950/80 backdrop-blur-xl">
      <div className="container mx-auto flex h-16 items-center justify-between px-6">
        <Link href="/" className="flex items-center gap-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600/20 text-blue-400">
            <BrainCircuit size={20} />
          </div>
          <span className="font-bold tracking-tight">NotebookLM</span>
          <span className="text-neutral-500 text-sm ml-2">/ Docs</span>
        </Link>
        <div className="flex items-center gap-4">
          <Link
            href="/login"
            className="text-sm font-medium text-neutral-400 hover:text-white transition-colors"
          >
            Log In
          </Link>
          <Link
            href="/"
            className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium hover:bg-blue-500 transition-colors"
          >
            Get Started
          </Link>
        </div>
      </div>
    </nav>
  );
}

function Sidebar() {
  const sections = [
    { id: "overview", label: "Overview", icon: BookOpen },
    { id: "quick-start", label: "Quick Start", icon: Zap },
    { id: "authentication", label: "Authentication", icon: Key },
    { id: "tools", label: "MCP Tools", icon: Code },
    { id: "configuration", label: "Configuration", icon: Settings },
    { id: "token-management", label: "Token Management", icon: Lock },
    { id: "architecture", label: "Architecture", icon: Cpu },
  ];

  return (
    <aside className="hidden lg:block">
      <div className="sticky top-24 space-y-1">
        <h3 className="text-xs font-semibold uppercase tracking-wider text-neutral-500 mb-4">
          MCP Integration
        </h3>
        {sections.map((section) => (
          <a
            key={section.id}
            href={`#${section.id}`}
            className="flex items-center gap-3 px-3 py-2 text-sm text-neutral-400 hover:text-white hover:bg-white/5 rounded-lg transition-colors"
          >
            <section.icon size={16} />
            {section.label}
          </a>
        ))}
      </div>
    </aside>
  );
}

function HeroSection() {
  return (
    <section id="overview" className="mb-16">
      <div className="flex items-center gap-3 mb-4">
        <div className="h-12 w-12 rounded-xl bg-blue-600/20 flex items-center justify-center">
          <Terminal className="text-blue-400" size={24} />
        </div>
        <div>
          <h1 className="text-3xl font-bold tracking-tight">MCP Server Documentation</h1>
          <p className="text-neutral-400">Connect coding agents to NotebookLM</p>
        </div>
      </div>
      <p className="text-lg text-neutral-300 leading-relaxed mt-6">
        The NotebookLM MCP (Model Context Protocol) server allows third-party coding agents 
        like Claude, Kiro, and Cursor to verify code and save it as sources in your notebooks. 
        This enables seamless integration between your AI coding workflow and research management.
      </p>
      <div className="grid sm:grid-cols-3 gap-4 mt-8">
        <FeatureCard
          icon={<Shield className="text-green-400" size={20} />}
          title="Secure Authentication"
          description="Personal API tokens with SHA-256 hashing"
        />
        <FeatureCard
          icon={<Code className="text-blue-400" size={20} />}
          title="Code Verification"
          description="Syntax, security, and best practices checks"
        />
        <FeatureCard
          icon={<FileCode className="text-purple-400" size={20} />}
          title="Source Management"
          description="Save verified code directly to notebooks"
        />
      </div>
    </section>
  );
}

function FeatureCard({ icon, title, description }: { icon: React.ReactNode; title: string; description: string }) {
  return (
    <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-4">
      <div className="flex items-center gap-3 mb-2">
        {icon}
        <h3 className="font-semibold">{title}</h3>
      </div>
      <p className="text-sm text-neutral-400">{description}</p>
    </div>
  );
}

function QuickStartSection() {
  return (
    <section id="quick-start" className="mb-16">
      <SectionHeader title="Quick Start" icon={<Zap className="text-amber-400" size={20} />} />
      
      <div className="space-y-6">
        <Step number={1} title="Generate a Personal API Token">
          <p className="text-neutral-400 mb-4">
            Before setting up the MCP server, generate a personal API token from the NotebookLM app:
          </p>
          <ol className="list-decimal list-inside space-y-2 text-neutral-300 text-sm">
            <li>Open the NotebookLM app</li>
            <li>Go to <strong>Settings</strong> → <strong>Agent Connections</strong></li>
            <li>In the <strong>API Tokens</strong> section, click <strong>Generate New Token</strong></li>
            <li>Enter a name for your token (e.g., "Kiro Coding Agent")</li>
            <li>Optionally set an expiration date</li>
            <li>Click <strong>Generate</strong> and copy the token immediately</li>
          </ol>
          <div className="mt-4 p-3 rounded-lg bg-amber-500/10 border border-amber-500/20 text-amber-200 text-sm">
            <strong>⚠️ Important:</strong> The token is only displayed once. If you lose it, you'll need to generate a new one.
          </div>
        </Step>

        <Step number={2} title="Configure Your MCP Client">
          <p className="text-neutral-400 mb-4">
            Add the following to your MCP configuration file (no installation needed):
          </p>
          <CodeBlock
            language="json"
            code={`{
  "mcpServers": {
    "notebookllm": {
      "command": "npx",
      "args": ["-y", "@notebookllm/mcp-server"],
      "env": {
        "CODING_AGENT_API_KEY": "nllm_your-token-here"
      }
    }
  }
}`}
          />
        </Step>

        <Step number={3} title="Start Using the Tools">
          <p className="text-neutral-400 mb-4">
            Once configured, your coding agent can use the MCP tools to verify code and save it to your notebooks.
            The server will automatically connect to the NotebookLM backend.
          </p>
        </Step>
      </div>
    </section>
  );
}

function AuthenticationSection() {
  return (
    <section id="authentication" className="mb-16">
      <SectionHeader title="Authentication" icon={<Key className="text-green-400" size={20} />} />
      
      <div className="space-y-6">
        <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-6">
          <h3 className="text-lg font-semibold mb-4">Token Format</h3>
          <p className="text-neutral-400 mb-4">
            Personal API tokens use a specific format for easy identification:
          </p>
          <CodeBlock
            language="text"
            code={`nllm_[43 characters of random data]

Example: nllm_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2`}
          />
          <ul className="mt-4 space-y-2 text-sm text-neutral-300">
            <li>• <strong>Prefix:</strong> <code className="text-blue-400">nllm_</code> (5 characters)</li>
            <li>• <strong>Random part:</strong> 43 characters (32 bytes base64url encoded)</li>
            <li>• <strong>Total length:</strong> 48 characters</li>
          </ul>
        </div>

        <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-6">
          <h3 className="text-lg font-semibold mb-4">Using the Token</h3>
          <p className="text-neutral-400 mb-4">
            Include the token in the Authorization header for API requests:
          </p>
          <CodeBlock
            language="bash"
            code={`curl -X POST http://localhost:3000/api/coding-agent/verify-and-save \\
  -H "Content-Type: application/json" \\
  -H "Authorization: Bearer nllm_your-token-here" \\
  -d '{
    "code": "function add(a, b) { return a + b; }",
    "language": "javascript",
    "title": "Add Function"
  }'`}
          />
        </div>

        <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-6">
          <h3 className="text-lg font-semibold mb-4">Security Features</h3>
          <div className="grid sm:grid-cols-2 gap-4">
            <div className="p-4 rounded-lg bg-white/5">
              <h4 className="font-medium mb-2 flex items-center gap-2">
                <Shield size={16} className="text-green-400" />
                SHA-256 Hashing
              </h4>
              <p className="text-sm text-neutral-400">
                Tokens are hashed before storage. The original token is never stored.
              </p>
            </div>
            <div className="p-4 rounded-lg bg-white/5">
              <h4 className="font-medium mb-2 flex items-center gap-2">
                <Lock size={16} className="text-blue-400" />
                Rate Limiting
              </h4>
              <p className="text-sm text-neutral-400">
                Maximum 5 new tokens per hour, 10 active tokens per user.
              </p>
            </div>
            <div className="p-4 rounded-lg bg-white/5">
              <h4 className="font-medium mb-2 flex items-center gap-2">
                <RefreshCw size={16} className="text-purple-400" />
                Instant Revocation
              </h4>
              <p className="text-sm text-neutral-400">
                Revoked tokens are immediately invalidated across all services.
              </p>
            </div>
            <div className="p-4 rounded-lg bg-white/5">
              <h4 className="font-medium mb-2 flex items-center gap-2">
                <FileCode size={16} className="text-amber-400" />
                Usage Logging
              </h4>
              <p className="text-sm text-neutral-400">
                All token usage is logged for security auditing.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}


function ToolsSection() {
  const tools = [
    {
      name: "verify_code",
      description: "Verify code for correctness, security vulnerabilities, and best practices.",
      params: [
        { name: "code", type: "string", required: true, description: "The code to verify" },
        { name: "language", type: "string", required: true, description: "Programming language" },
        { name: "context", type: "string", required: false, description: "Additional context" },
        { name: "strictMode", type: "boolean", required: false, description: "Enable strict checking" },
      ],
      example: `{
  "code": "function hello() { return 'world'; }",
  "language": "javascript",
  "context": "A simple greeting function",
  "strictMode": false
}`,
    },
    {
      name: "verify_and_save",
      description: "Verify code and save it as a source if it passes verification (score >= 60).",
      params: [
        { name: "code", type: "string", required: true, description: "The code to verify and save" },
        { name: "language", type: "string", required: true, description: "Programming language" },
        { name: "title", type: "string", required: true, description: "Title for the source" },
        { name: "description", type: "string", required: false, description: "Description of the code" },
        { name: "notebookId", type: "string", required: false, description: "Target notebook ID" },
      ],
      example: `{
  "code": "const add = (a, b) => a + b;",
  "language": "javascript",
  "title": "Add Function",
  "description": "Simple addition utility",
  "notebookId": "optional-notebook-id"
}`,
    },
    {
      name: "batch_verify",
      description: "Verify multiple code snippets at once.",
      params: [
        { name: "snippets", type: "array", required: true, description: "Array of code snippets" },
      ],
      example: `{
  "snippets": [
    { "id": "1", "code": "...", "language": "python" },
    { "id": "2", "code": "...", "language": "typescript" }
  ]
}`,
    },
    {
      name: "analyze_code",
      description: "Deep analysis with comprehensive suggestions using AI.",
      params: [
        { name: "code", type: "string", required: true, description: "The code to analyze" },
        { name: "language", type: "string", required: true, description: "Programming language" },
        { name: "analysisType", type: "string", required: false, description: "Type: security, performance, or all" },
      ],
      example: `{
  "code": "...",
  "language": "python",
  "analysisType": "security"
}`,
    },
    {
      name: "get_verified_sources",
      description: "Retrieve previously saved verified code sources.",
      params: [
        { name: "notebookId", type: "string", required: false, description: "Filter by notebook" },
        { name: "language", type: "string", required: false, description: "Filter by language" },
      ],
      example: `{
  "notebookId": "optional-filter",
  "language": "optional-filter"
}`,
    },
  ];

  return (
    <section id="tools" className="mb-16">
      <SectionHeader title="MCP Tools" icon={<Code className="text-blue-400" size={20} />} />
      
      <div className="space-y-6">
        {tools.map((tool) => (
          <ToolCard key={tool.name} tool={tool} />
        ))}
      </div>
    </section>
  );
}

function ToolCard({ tool }: { tool: any }) {
  const [isExpanded, setIsExpanded] = useState(false);

  return (
    <div className="rounded-xl border border-white/5 bg-neutral-900/50 overflow-hidden">
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="w-full p-6 flex items-center justify-between hover:bg-white/5 transition-colors"
      >
        <div className="flex items-center gap-4">
          <code className="text-blue-400 font-mono text-lg">{tool.name}</code>
          <span className="text-neutral-400 text-sm hidden sm:block">{tool.description}</span>
        </div>
        {isExpanded ? <ChevronDown size={20} /> : <ChevronRight size={20} />}
      </button>
      
      <AnimatePresence>
        {isExpanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="border-t border-white/5"
          >
            <div className="p-6 space-y-6">
              <p className="text-neutral-300 sm:hidden">{tool.description}</p>
              
              <div>
                <h4 className="text-sm font-semibold text-neutral-200 mb-3">Parameters</h4>
                <div className="space-y-2">
                  {tool.params.map((param: any) => (
                    <div key={param.name} className="flex items-start gap-3 text-sm">
                      <code className="text-purple-400 font-mono">{param.name}</code>
                      <span className="text-neutral-500">{param.type}</span>
                      {param.required && (
                        <span className="px-1.5 py-0.5 text-xs bg-red-500/20 text-red-400 rounded">required</span>
                      )}
                      <span className="text-neutral-400">{param.description}</span>
                    </div>
                  ))}
                </div>
              </div>

              <div>
                <h4 className="text-sm font-semibold text-neutral-200 mb-3">Example</h4>
                <CodeBlock language="json" code={tool.example} />
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

function ConfigurationSection() {
  return (
    <section id="configuration" className="mb-16">
      <SectionHeader title="Configuration" icon={<Settings className="text-purple-400" size={20} />} />
      
      <div className="space-y-6">
        <div className="rounded-xl border border-blue-500/20 bg-blue-500/5 p-6">
          <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
            <Zap className="text-blue-400" size={20} />
            Recommended: NPX Configuration
          </h3>
          <p className="text-neutral-400 mb-4">
            The easiest way to use the MCP server - no local installation required:
          </p>
          <CodeBlock
            language="json"
            code={`{
  "mcpServers": {
    "notebookllm": {
      "command": "npx",
      "args": ["-y", "@notebookllm/mcp-server"],
      "env": {
        "CODING_AGENT_API_KEY": "nllm_your-personal-api-token-here"
      }
    }
  }
}`}
          />
        </div>

        <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-6">
          <h3 className="text-lg font-semibold mb-4">Kiro Configuration</h3>
          <p className="text-neutral-400 mb-4">
            Add to <code className="text-blue-400">.kiro/settings/mcp.json</code>:
          </p>
          <CodeBlock
            language="json"
            code={`{
  "mcpServers": {
    "notebookllm": {
      "command": "npx",
      "args": ["-y", "@notebookllm/mcp-server"],
      "env": {
        "CODING_AGENT_API_KEY": "nllm_your-personal-api-token-here"
      }
    }
  }
}`}
          />
        </div>

        <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-6">
          <h3 className="text-lg font-semibold mb-4">Claude Desktop Configuration</h3>
          <p className="text-neutral-400 mb-4">
            Add to <code className="text-blue-400">claude_desktop_config.json</code>:
          </p>
          <CodeBlock
            language="json"
            code={`{
  "mcpServers": {
    "notebookllm": {
      "command": "npx",
      "args": ["-y", "@notebookllm/mcp-server"],
      "env": {
        "CODING_AGENT_API_KEY": "nllm_your-personal-api-token-here"
      }
    }
  }
}`}
          />
        </div>

        <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-6">
          <h3 className="text-lg font-semibold mb-4">Alternative: Local Installation</h3>
          <p className="text-neutral-400 mb-4">
            If you prefer to run the server locally:
          </p>
          <CodeBlock
            language="bash"
            code={`# Clone and build
cd backend/mcp-server
npm install
npm run build

# Then configure with absolute path
{
  "mcpServers": {
    "notebookllm": {
      "command": "node",
      "args": ["/path/to/backend/mcp-server/dist/index.js"],
      "env": {
        "CODING_AGENT_API_KEY": "nllm_your-token"
      }
    }
  }
}`}
          />
        </div>
      </div>
    </section>
  );
}

function TokenManagementSection() {
  return (
    <section id="token-management" className="mb-16">
      <SectionHeader title="Token Management" icon={<Lock className="text-amber-400" size={20} />} />
      
      <div className="space-y-6">
        <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-6">
          <h3 className="text-lg font-semibold mb-4">Viewing Your Tokens</h3>
          <p className="text-neutral-400 mb-4">
            In the NotebookLM app, go to <strong>Settings</strong> → <strong>Agent Connections</strong> to see all your active tokens:
          </p>
          <ul className="space-y-2 text-sm text-neutral-300">
            <li>• Token name and description</li>
            <li>• Creation date</li>
            <li>• Last used date (updated each time the token is used)</li>
            <li>• Partial token display (last 4 characters for identification)</li>
          </ul>
        </div>

        <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-6">
          <h3 className="text-lg font-semibold mb-4">Revoking a Token</h3>
          <p className="text-neutral-400 mb-4">
            If a token is compromised or no longer needed:
          </p>
          <ol className="list-decimal list-inside space-y-2 text-sm text-neutral-300">
            <li>Go to <strong>Settings</strong> → <strong>Agent Connections</strong></li>
            <li>Find the token in the list</li>
            <li>Click the <strong>Revoke</strong> button</li>
            <li>Confirm the revocation</li>
          </ol>
          <div className="mt-4 p-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-200 text-sm">
            <strong>Note:</strong> Revoked tokens are immediately invalidated. Any MCP server using that token will receive authentication errors.
          </div>
        </div>

        <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-6">
          <h3 className="text-lg font-semibold mb-4">Token Limits</h3>
          <div className="grid sm:grid-cols-3 gap-4">
            <div className="p-4 rounded-lg bg-white/5 text-center">
              <div className="text-2xl font-bold text-blue-400">10</div>
              <div className="text-sm text-neutral-400">Max active tokens</div>
            </div>
            <div className="p-4 rounded-lg bg-white/5 text-center">
              <div className="text-2xl font-bold text-purple-400">5</div>
              <div className="text-sm text-neutral-400">New tokens per hour</div>
            </div>
            <div className="p-4 rounded-lg bg-white/5 text-center">
              <div className="text-2xl font-bold text-green-400">∞</div>
              <div className="text-sm text-neutral-400">Optional expiration</div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function ArchitectureSection() {
  return (
    <section id="architecture" className="mb-16">
      <SectionHeader title="Architecture" icon={<Cpu className="text-cyan-400" size={20} />} />
      
      <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-6">
        <div className="font-mono text-sm text-neutral-300 whitespace-pre overflow-x-auto">
{`┌─────────────────────────────────────────────────────────────┐
│                    Third-Party Agents                        │
│              (Claude, Kiro, Cursor, etc.)                   │
└─────────────────────┬───────────────────────────────────────┘
                      │ MCP Protocol (stdio)
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Coding Agent MCP Server                         │
│         backend/mcp-server/src/index.ts                     │
│                                                              │
│  Tools:                                                      │
│  • verify_code - Check code correctness                     │
│  • verify_and_save - Verify & save as source                │
│  • batch_verify - Verify multiple snippets                  │
│  • analyze_code - Deep analysis                             │
│  • get_verified_sources - Retrieve saved sources            │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTP API + Bearer Token
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   Backend API                                │
│            /api/coding-agent/*                              │
│                                                              │
│  Authentication:                                             │
│  • Personal API tokens (nllm_xxx format)                    │
│  • SHA-256 hashed storage                                   │
│  • Usage logging & rate limiting                            │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│            Code Verification Service                         │
│    backend/src/services/codeVerificationService.ts          │
│                                                              │
│  Features:                                                   │
│  • Syntax validation (JS/TS, Python, Dart, JSON)           │
│  • Security scanning (XSS, SQL injection, secrets)         │
│  • AI-powered analysis (Gemini)                             │
│  • Best practices checking                                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   Database                                   │
│              sources table + api_tokens table               │
│                                                              │
│  Stores:                                                     │
│  • Verified code with metadata                              │
│  • Token hashes and usage logs                              │
│  • User/notebook associations                               │
└─────────────────────────────────────────────────────────────┘`}
        </div>
      </div>

      <div className="mt-6 rounded-xl border border-white/5 bg-neutral-900/50 p-6">
        <h3 className="text-lg font-semibold mb-4">Verification Scoring</h3>
        <p className="text-neutral-400 mb-4">
          Code must score ≥ 60 to be saved as a source. Scoring is based on:
        </p>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/10">
                <th className="text-left py-2 text-neutral-400">Severity</th>
                <th className="text-left py-2 text-neutral-400">Error Impact</th>
                <th className="text-left py-2 text-neutral-400">Warning Impact</th>
              </tr>
            </thead>
            <tbody className="text-neutral-300">
              <tr className="border-b border-white/5">
                <td className="py-2 text-red-400">Critical</td>
                <td className="py-2">-25 points</td>
                <td className="py-2">-10 points</td>
              </tr>
              <tr className="border-b border-white/5">
                <td className="py-2 text-orange-400">High</td>
                <td className="py-2">-15 points</td>
                <td className="py-2">-5 points</td>
              </tr>
              <tr className="border-b border-white/5">
                <td className="py-2 text-amber-400">Medium</td>
                <td className="py-2">-10 points</td>
                <td className="py-2">-3 points</td>
              </tr>
              <tr>
                <td className="py-2 text-yellow-400">Low</td>
                <td className="py-2">-5 points</td>
                <td className="py-2">-1 point</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div className="mt-6 rounded-xl border border-white/5 bg-neutral-900/50 p-6">
        <h3 className="text-lg font-semibold mb-4">Supported Languages</h3>
        <div className="flex flex-wrap gap-2">
          {["JavaScript", "TypeScript", "Python", "Dart", "JSON", "Generic"].map((lang) => (
            <span
              key={lang}
              className="px-3 py-1 rounded-full bg-white/5 text-sm text-neutral-300 border border-white/10"
            >
              {lang}
            </span>
          ))}
        </div>
      </div>
    </section>
  );
}

// Helper Components

function SectionHeader({ title, icon }: { title: string; icon: React.ReactNode }) {
  return (
    <div className="flex items-center gap-3 mb-6 pb-4 border-b border-white/5">
      {icon}
      <h2 className="text-2xl font-bold">{title}</h2>
    </div>
  );
}

function Step({ number, title, children }: { number: number; title: string; children: React.ReactNode }) {
  return (
    <div className="flex gap-4">
      <div className="flex-shrink-0 w-8 h-8 rounded-full bg-blue-600/20 text-blue-400 flex items-center justify-center font-bold text-sm">
        {number}
      </div>
      <div className="flex-1">
        <h3 className="text-lg font-semibold mb-3">{title}</h3>
        {children}
      </div>
    </div>
  );
}

function CodeBlock({ language, code }: { language: string; code: string }) {
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="relative rounded-lg bg-neutral-800/50 border border-white/5 overflow-hidden">
      <div className="flex items-center justify-between px-4 py-2 border-b border-white/5 bg-white/5">
        <span className="text-xs text-neutral-500 font-mono">{language}</span>
        <button
          onClick={handleCopy}
          className="flex items-center gap-1 text-xs text-neutral-400 hover:text-white transition-colors"
        >
          {copied ? <Check size={14} /> : <Copy size={14} />}
          {copied ? "Copied!" : "Copy"}
        </button>
      </div>
      <pre className="p-4 overflow-x-auto text-sm">
        <code className="text-neutral-300">{code}</code>
      </pre>
    </div>
  );
}

function Footer() {
  return (
    <footer className="border-t border-white/5 bg-neutral-950 py-12">
      <div className="container mx-auto px-6">
        <div className="flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <BrainCircuit className="text-blue-400" size={20} />
            <span className="font-bold">NotebookLM</span>
          </div>
          <div className="flex items-center gap-6 text-sm text-neutral-500">
            <Link href="/" className="hover:text-white transition-colors">Home</Link>
            <Link href="/login" className="hover:text-white transition-colors">Login</Link>
            <a
              href="https://github.com"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-white transition-colors flex items-center gap-1"
            >
              GitHub <ExternalLink size={12} />
            </a>
          </div>
          <p className="text-sm text-neutral-500">© 2025 NotebookLM</p>
        </div>
      </div>
    </footer>
  );
}
