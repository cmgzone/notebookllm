import type { Request, Response } from 'express';
import axios from 'axios';

interface YouTubeExtractRequest {
    url: string;
    videoId?: string;
}

/**
 * Extract content from YouTube videos
 * Gets video metadata and transcript
 */
export const extractYouTubeContent = async (req: Request, res: Response) => {
    try {
        const { url, videoId } = req.body as YouTubeExtractRequest;

        if (!url && !videoId) {
            return res.status(400).json({
                success: false,
                error: 'URL or videoId is required'
            });
        }

        // Extract video ID from URL if not provided
        const extractedVideoId = videoId || extractVideoIdFromUrl(url);

        if (!extractedVideoId) {
            return res.status(400).json({
                success: false,
                error: 'Invalid YouTube URL'
            });
        }

        // Get video metadata
        const metadata = await getVideoMetadata(url);

        // Get transcript
        const transcript = await getVideoTranscript(extractedVideoId);

        const content = formatYouTubeContent(metadata, transcript, extractedVideoId, url);

        return res.json({
            success: true,
            content,
            metadata: {
                videoId: extractedVideoId,
                title: metadata.title,
                author: metadata.author,
                duration: metadata.duration,
                hasTranscript: transcript.length > 0
            }
        });

    } catch (error: any) {
        console.error('YouTube extraction error:', error);
        return res.status(500).json({
            success: false,
            error: error.message || 'Failed to extract YouTube content'
        });
    }
};

/**
 * Extract video ID from various YouTube URL formats
 */
function extractVideoIdFromUrl(url: string): string | null {
    const patterns = [
        /youtu\.be\/([a-zA-Z0-9_-]{11})/,
        /youtube\.com\/watch\?v=([a-zA-Z0-9_-]{11})/,
        /youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/,
        /youtube\.com\/v\/([a-zA-Z0-9_-]{11})/,
        /youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})/,
    ];

    for (const pattern of patterns) {
        const match = url.match(pattern);
        if (match) {
            return match[1];
        }
    }

    return null;
}

/**
 * Get video metadata using noembed service
 */
async function getVideoMetadata(url: string): Promise<any> {
    try {
        const response = await axios.get(`https://noembed.com/embed?url=${encodeURIComponent(url)}`, {
            timeout: 10000
        });

        return {
            title: response.data.title || 'YouTube Video',
            author: response.data.author_name || 'Unknown',
            duration: response.data.duration || null
        };
    } catch (error) {
        console.warn('Failed to get YouTube metadata:', error);
        return {
            title: 'YouTube Video',
            author: 'Unknown',
            duration: null
        };
    }
}

/**
 * Get video transcript using public API
 */
async function getVideoTranscript(videoId: string): Promise<string> {
    try {
        // Try public transcript service
        const response = await axios.get(
            `https://yt-transcript-api.vercel.app/api/transcript?videoId=${videoId}`,
            { timeout: 15000 }
        );

        if (response.status === 200 && Array.isArray(response.data)) {
            return response.data.map((item: any) => item.text || '').join(' ');
        }
    } catch (error) {
        console.warn('Transcript fetch failed:', error);
    }

    return '';
}

/**
 * Format YouTube content for storage
 */
function formatYouTubeContent(metadata: any, transcript: string, videoId: string, url: string): string {
    const content: any[] = [];

    content.push(`# ${metadata.title}`);

    if (metadata.author) {
        content.push(`By: ${metadata.author}`);
    }

    content.push('');
    content.push(`Video ID: ${videoId}`);
    content.push(`URL: ${url}`);

    if (transcript) {
        content.push('');
        content.push('## Transcript');
        content.push(transcript);
    } else {
        content.push('');
        content.push('## Note');
        content.push('Transcript not available for this video.');
    }

    return content.join('\n');
}
