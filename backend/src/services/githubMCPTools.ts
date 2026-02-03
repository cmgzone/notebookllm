import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { githubService } from './githubService.js';

/**
 * Tool: List Repositories
 */
const listReposTool: MCPTool = {
    name: 'github_list_repos',
    description: 'List GitHub repositories for the connected user. Use this tool instead of shell commands like `git` or `gh` CLI.',
    schema: {
        type: 'object',
        properties: {
            type: { type: 'string', enum: ['all', 'owner', 'member'], description: 'Type of repositories to list (default: all)' },
            sort: { type: 'string', enum: ['created', 'updated', 'pushed', 'full_name'], description: 'Sort order (default: updated)' },
            perPage: { type: 'number', description: 'Number of repos per page (default: 30)' }
        }
    },
    handler: async (args: any, context: MCPContext) => {
        const { type, sort, perPage } = args;
        return await githubService.listRepos(context.userId, { type, sort, perPage });
    }
};

/**
 * Tool: Get Repository Tree
 */
const getRepoTreeTool: MCPTool = {
    name: 'github_get_tree',
    description: 'Get the file tree of a GitHub repository. Use this tool instead of shell commands.',
    schema: {
        type: 'object',
        properties: {
            owner: { type: 'string', description: 'Repository owner' },
            repo: { type: 'string', description: 'Repository name' },
            branch: { type: 'string', description: 'Branch name (optional, defaults to default branch)' }
        },
        required: ['owner', 'repo']
    },
    handler: async (args: any, context: MCPContext) => {
        const { owner, repo, branch } = args;
        return await githubService.getRepoTree(context.userId, owner, repo, branch);
    }
};

/**
 * Tool: Read File Content
 */
const readFileTool: MCPTool = {
    name: 'github_read_file',
    description: 'Read the content of a file from a GitHub repository. Use this tool instead of shell commands.',
    schema: {
        type: 'object',
        properties: {
            owner: { type: 'string', description: 'Repository owner' },
            repo: { type: 'string', description: 'Repository name' },
            path: { type: 'string', description: 'File path' },
            branch: { type: 'string', description: 'Branch name (optional)' }
        },
        required: ['owner', 'repo', 'path']
    },
    handler: async (args: any, context: MCPContext) => {
        const { owner, repo, path, branch } = args;
        return await githubService.getFileContent(context.userId, owner, repo, path, branch);
    }
};

/**
 * Tool: Search Code
 */
const searchCodeTool: MCPTool = {
    name: 'github_search_code',
    description: 'Search for code in GitHub repositories. Use this tool instead of shell commands.',
    schema: {
        type: 'object',
        properties: {
            query: { type: 'string', description: 'Search query' },
            repo: { type: 'string', description: 'Limit search to a specific repository (owner/name)' },
            language: { type: 'string', description: 'Limit search to a specific language' },
            path: { type: 'string', description: 'Limit search to a specific path' }
        },
        required: ['query']
    },
    handler: async (args: any, context: MCPContext) => {
        const { query, repo, language, path } = args;
        return await githubService.searchCode(context.userId, query, { repo, language, path });
    }
};

/**
 * Tool: Create Issue
 */
const createIssueTool: MCPTool = {
    name: 'github_create_issue',
    description: 'Create a new issue in a GitHub repository.',
    schema: {
        type: 'object',
        properties: {
            owner: { type: 'string', description: 'Repository owner' },
            repo: { type: 'string', description: 'Repository name' },
            title: { type: 'string', description: 'Issue title' },
            body: { type: 'string', description: 'Issue body/description' },
            labels: { type: 'array', items: { type: 'string' }, description: 'Labels to apply' }
        },
        required: ['owner', 'repo', 'title']
    },
    handler: async (args: any, context: MCPContext) => {
        const { owner, repo, title, body, labels } = args;
        return await githubService.createIssue(context.userId, owner, repo, title, body, labels);
    }
};

/**
 * Tool: Comment on Issue
 */
const commentIssueTool: MCPTool = {
    name: 'github_comment_issue',
    description: 'Add a comment to a GitHub issue or pull request.',
    schema: {
        type: 'object',
        properties: {
            owner: { type: 'string', description: 'Repository owner' },
            repo: { type: 'string', description: 'Repository name' },
            issueNumber: { type: 'number', description: 'Issue or PR number' },
            body: { type: 'string', description: 'Comment body' }
        },
        required: ['owner', 'repo', 'issueNumber', 'body']
    },
    handler: async (args: any, context: MCPContext) => {
        const { owner, repo, issueNumber, body } = args;
        return await githubService.addComment(context.userId, owner, repo, issueNumber, body);
    }
};

/**
 * Register GitHub Tools
 */
export function registerGitHubTools() {
    gituMCPHub.registerTool(listReposTool);
    gituMCPHub.registerTool(getRepoTreeTool);
    gituMCPHub.registerTool(readFileTool);
    gituMCPHub.registerTool(searchCodeTool);
    gituMCPHub.registerTool(createIssueTool);
    gituMCPHub.registerTool(commentIssueTool);
    console.log('[GitHubMCPTools] Registered GitHub tools');
}
