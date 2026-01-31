import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import axios from 'axios';

/**
 * Service Logic (Duplicated from googleDriveController to avoid coupling)
 */
function extractFileIdFromUrl(url: string): string | null {
    const patterns = [
        /drive\.google\.com\/file\/d\/([a-zA-Z0-9_-]+)/,
        /drive\.google\.com\/open\?id=([a-zA-Z0-9_-]+)/,
        /docs\.google\.com\/document\/d\/([a-zA-Z0-9_-]+)/,
        /docs\.google\.com\/spreadsheets\/d\/([a-zA-Z0-9_-]+)/,
        /docs\.google\.com\/presentation\/d\/([a-zA-Z0-9_-]+)/,
    ];
    for (const pattern of patterns) {
        const match = url.match(pattern);
        if (match) return match[1];
    }
    return null;
}

function detectFileType(url: string): string {
    if (url.includes('docs.google.com/document')) return 'document';
    if (url.includes('docs.google.com/spreadsheets')) return 'spreadsheet';
    if (url.includes('docs.google.com/presentation')) return 'presentation';
    return 'file';
}

async function exportGoogleDoc(fileId: string): Promise<string> {
    const exportUrl = `https://docs.google.com/document/d/${fileId}/export?format=txt`;
    const response = await axios.get(exportUrl, { timeout: 30000 });
    return response.data;
}

async function exportGoogleSheet(fileId: string): Promise<string> {
    const exportUrl = `https://docs.google.com/spreadsheets/d/${fileId}/export?format=csv`;
    const response = await axios.get(exportUrl, { timeout: 30000 });
    const lines = response.data.split('\n');
    return lines.slice(0, 500).join('\n') + (lines.length > 500 ? `\n... (${lines.length - 500} more rows)` : '');
}

async function exportGoogleSlides(fileId: string): Promise<string> {
    // Basic text export
    try {
        const exportUrl = `https://docs.google.com/presentation/d/${fileId}/export?format=txt`;
        const response = await axios.get(exportUrl, { timeout: 30000 });
        return response.data;
    } catch {
        return "Google Slides content could not be extracted as text.";
    }
}

async function downloadFile(fileId: string): Promise<string> {
    const downloadUrl = `https://drive.google.com/uc?export=download&id=${fileId}`;
    const response = await axios.get(downloadUrl, {
        timeout: 30000,
        maxContentLength: 10 * 1024 * 1024
    });
    if (typeof response.data === 'string') return response.data;
    return `Binary file (ID: ${fileId}) - Content not viewable as text.`;
}

/**
 * Tool: Read Google Doc
 */
const readGoogleDocTool: MCPTool = {
    name: 'read_google_doc',
    description: 'Read the content of a public Google Drive file (Docs, Sheets, Slides) via URL.',
    schema: {
        type: 'object',
        properties: {
            url: { type: 'string', description: 'The public Google Drive URL' }
        },
        required: ['url']
    },
    handler: async (args: any, context: MCPContext) => {
        const { url } = args;
        const fileId = extractFileIdFromUrl(url);
        if (!fileId) throw new Error('Invalid Google Drive URL.');

        const fileType = detectFileType(url);
        let content = '';

        try {
            switch (fileType) {
                case 'document': content = await exportGoogleDoc(fileId); break;
                case 'spreadsheet': content = await exportGoogleSheet(fileId); break;
                case 'presentation': content = await exportGoogleSlides(fileId); break;
                default: content = await downloadFile(fileId);
            }

            return {
                success: true,
                fileId,
                fileType,
                content
            };
        } catch (e: any) {
            throw new Error(`Failed to read Google Drive file: ${e.message}. Ensure it is shared publicly ("Anyone with link").`);
        }
    }
};

/**
 * Register Google Drive Tools
 */
export function registerGoogleDriveTools() {
    gituMCPHub.registerTool(readGoogleDocTool);
    console.log('[GoogleDriveMCPTools] Registered read_google_doc tool');
}
