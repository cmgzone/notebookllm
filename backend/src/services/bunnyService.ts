import crypto from 'crypto';

interface BunnyConfig {
    storageZoneName: string;
    storageApiKey: string;
    cdnHostname: string;
    storageHostname: string;
}

interface UploadResult {
    success: boolean;
    url?: string;
    cdnUrl?: string;
    path?: string;
    error?: string;
}

class BunnyService {
    private config: BunnyConfig | null = null;

    initialize() {
        const storageZoneName = process.env.BUNNY_STORAGE_ZONE;
        const storageApiKey = process.env.BUNNY_STORAGE_API_KEY;
        const cdnHostname = process.env.BUNNY_CDN_HOSTNAME;
        const storageHostname = process.env.BUNNY_STORAGE_HOSTNAME || 'storage.bunnycdn.com';

        if (!storageZoneName || !storageApiKey) {
            console.warn('Bunny.net not configured - media will be stored in database');
            return;
        }

        this.config = {
            storageZoneName,
            storageApiKey,
            cdnHostname: cdnHostname || `${storageZoneName}.b-cdn.net`,
            storageHostname,
        };

        console.log('Bunny.net CDN initialized:', this.config.cdnHostname);
    }

    isConfigured(): boolean {
        return this.config !== null;
    }

    /**
     * Generate a unique file path for storage
     */
    generatePath(userId: string, filename: string, type: string): string {
        const timestamp = Date.now();
        const hash = crypto.createHash('md5').update(`${userId}-${timestamp}`).digest('hex').substring(0, 8);
        const ext = filename.split('.').pop() || this.getExtensionForType(type);
        const sanitizedFilename = filename.replace(/[^a-zA-Z0-9.-]/g, '_').substring(0, 50);
        
        // Organize by type and user
        return `${type}/${userId}/${hash}-${sanitizedFilename}`;
    }

    private getExtensionForType(type: string): string {
        switch (type) {
            case 'image':
            case 'photo':
                return 'png';
            case 'audio':
            case 'podcast':
                return 'mp3';
            case 'video':
                return 'mp4';
            case 'pdf':
                return 'pdf';
            default:
                return 'bin';
        }
    }

    /**
     * Upload a file to Bunny.net Storage
     */
    async upload(buffer: Buffer, path: string): Promise<UploadResult> {
        if (!this.config) {
            return { success: false, error: 'Bunny.net not configured' };
        }

        const url = `https://${this.config.storageHostname}/${this.config.storageZoneName}/${path}`;

        try {
            const response = await fetch(url, {
                method: 'PUT',
                headers: {
                    'AccessKey': this.config.storageApiKey,
                    'Content-Type': 'application/octet-stream',
                },
                body: buffer,
            });

            if (!response.ok) {
                const text = await response.text();
                console.error('Bunny upload failed:', response.status, text);
                return { success: false, error: `Upload failed: ${response.status}` };
            }

            const cdnUrl = `https://${this.config.cdnHostname}/${path}`;

            return {
                success: true,
                url,
                cdnUrl,
                path,
            };
        } catch (error) {
            console.error('Bunny upload error:', error);
            return { success: false, error: String(error) };
        }
    }

    /**
     * Delete a file from Bunny.net Storage
     */
    async delete(path: string): Promise<boolean> {
        if (!this.config) {
            return false;
        }

        const url = `https://${this.config.storageHostname}/${this.config.storageZoneName}/${path}`;

        try {
            const response = await fetch(url, {
                method: 'DELETE',
                headers: {
                    'AccessKey': this.config.storageApiKey,
                },
            });

            return response.ok;
        } catch (error) {
            console.error('Bunny delete error:', error);
            return false;
        }
    }

    /**
     * Get the CDN URL for a stored file
     */
    getCdnUrl(path: string): string | null {
        if (!this.config) return null;
        return `https://${this.config.cdnHostname}/${path}`;
    }

    /**
     * Download a file from Bunny.net Storage
     */
    async download(path: string): Promise<Buffer | null> {
        if (!this.config) return null;

        const url = `https://${this.config.storageHostname}/${this.config.storageZoneName}/${path}`;

        try {
            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'AccessKey': this.config.storageApiKey,
                },
            });

            if (!response.ok) {
                return null;
            }

            const arrayBuffer = await response.arrayBuffer();
            return Buffer.from(arrayBuffer);
        } catch (error) {
            console.error('Bunny download error:', error);
            return null;
        }
    }

    /**
     * List files in a directory
     */
    async listFiles(directory: string): Promise<string[]> {
        if (!this.config) return [];

        const url = `https://${this.config.storageHostname}/${this.config.storageZoneName}/${directory}/`;

        try {
            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'AccessKey': this.config.storageApiKey,
                    'Accept': 'application/json',
                },
            });

            if (!response.ok) {
                return [];
            }

            const files = await response.json() as Array<{ ObjectName: string }>;
            return files.map(f => f.ObjectName);
        } catch (error) {
            console.error('Bunny list error:', error);
            return [];
        }
    }

    /**
     * Get storage statistics
     */
    async getStorageStats(): Promise<{ totalSize: number; fileCount: number } | null> {
        // Bunny.net doesn't have a direct stats API, would need to iterate
        // For now, return null and track in database
        return null;
    }
}

export const bunnyService = new BunnyService();
export default bunnyService;
