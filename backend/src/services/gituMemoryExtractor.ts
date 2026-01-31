/**
 * Gitu Memory Extractor Service
 * Automatically extracts memorable facts from conversations and stores them.
 * 
 * This service analyzes user messages and AI responses to identify:
 * - Personal facts (name, birthday, preferences)
 * - Work/project information
 * - Preferences and interests
 * - Important dates and events
 */

import { gituMemoryService, MemoryCategory } from './gituMemoryService.js';
import { generateWithGemini } from './aiService.js';

export interface ExtractedFact {
    content: string;
    category: MemoryCategory;
    confidence: number;
    source: string;
}

class GituMemoryExtractor {
    /**
     * Extract memorable facts from a conversation turn.
     * This should be called after each user message or conversation.
     */
    async extractFromConversation(
        userId: string,
        userMessage: string,
        assistantResponse: string,
        options: {
            platform?: string;
            sessionId?: string;
        } = {}
    ): Promise<ExtractedFact[]> {
        const { platform = 'web', sessionId } = options;

        // Quick filter: Skip if message is too short or is a simple question
        if (userMessage.length < 20 || this.isSimpleQuery(userMessage)) {
            return [];
        }

        try {
            // Use AI to extract facts
            const facts = await this.extractFactsWithAI(userMessage, assistantResponse);

            // Store extracted facts
            for (const fact of facts) {
                if (fact.confidence >= 0.6) {
                    try {
                        await gituMemoryService.createMemory(userId, {
                            content: fact.content,
                            category: fact.category,
                            source: `${platform}:${sessionId || 'unknown'}`,
                            tags: [platform, 'auto-extracted'],
                            confidence: fact.confidence,
                        });
                        console.log(`[MemoryExtractor] Stored fact: "${fact.content.substring(0, 50)}..."`);
                    } catch (error) {
                        // Ignore duplicate or storage errors
                        console.warn('[MemoryExtractor] Failed to store fact:', error);
                    }
                }
            }

            return facts;
        } catch (error) {
            console.error('[MemoryExtractor] Error extracting facts:', error);
            return [];
        }
    }

    /**
     * Check if a message is a simple query that won't contain memorable facts.
     */
    private isSimpleQuery(message: string): boolean {
        const lowerMessage = message.toLowerCase().trim();

        // Simple greetings
        if (/^(hi|hello|hey|good morning|good afternoon|good evening|thanks|thank you|bye|goodbye)[\s!.]*$/i.test(lowerMessage)) {
            return true;
        }

        // Simple questions without personal info
        if (/^(what|how|why|when|where|who|can you|could you|will you|would you)\s+(is|are|do|does|did|can|could|will|would)?\s*\w+\s*\??$/i.test(lowerMessage)) {
            return true;
        }

        return false;
    }

    /**
     * Use AI to extract facts from a conversation.
     */
    private async extractFactsWithAI(userMessage: string, assistantResponse: string): Promise<ExtractedFact[]> {
        const prompt = `Analyze this conversation and extract any personal facts about the user that should be remembered for future conversations.

User said: "${userMessage}"

Assistant responded: "${assistantResponse.substring(0, 500)}"

Extract facts that are:
- Personal preferences (favorite things, likes, dislikes)
- Personal information (name, birthday, location, job)
- Work/project details (current projects, goals)
- Relationships (family, friends mentioned)
- Interests and hobbies

Respond with a JSON array of facts. Each fact should have:
- "content": A clear, standalone statement about the user (e.g., "User's favorite color is blue")
- "category": One of "fact", "preference", "goal", "work", "relationship"
- "confidence": A number from 0 to 1 indicating how confident you are this is a real fact

If no significant facts are found, return an empty array: []

Only include facts that are clearly stated or strongly implied. Don't make assumptions.

JSON response:`;

        try {
            const response = await generateWithGemini(
                [{ role: 'user', content: prompt }],
                'gemini-2.0-flash'
            );

            // Parse the JSON response
            const jsonMatch = response.match(/\[[\s\S]*\]/);
            if (!jsonMatch) {
                return [];
            }

            const parsed = JSON.parse(jsonMatch[0]);

            if (!Array.isArray(parsed)) {
                return [];
            }

            return parsed.map((item: any) => ({
                content: String(item.content || ''),
                category: this.mapCategory(item.category),
                confidence: Number(item.confidence) || 0.5,
                source: 'ai-extraction',
            })).filter((f: ExtractedFact) => f.content.length > 0);

        } catch (error) {
            console.warn('[MemoryExtractor] AI extraction failed:', error);
            return [];
        }
    }

    /**
     * Map extracted category to MemoryCategory.
     */
    private mapCategory(category: string): MemoryCategory {
        const lower = (category || '').toLowerCase();

        if (lower.includes('preference')) return 'preference';
        if (lower.includes('goal')) return 'goal';
        if (lower.includes('work') || lower.includes('project')) return 'work';
        if (lower.includes('relationship') || lower.includes('family')) return 'relationship';

        return 'fact';
    }

    /**
     * Extract facts from a batch of messages (e.g., when reviewing history).
     */
    async extractFromHistory(
        userId: string,
        messages: Array<{ role: string; content: string }>,
        options: { platform?: string } = {}
    ): Promise<ExtractedFact[]> {
        const allFacts: ExtractedFact[] = [];

        // Process in pairs (user message + assistant response)
        for (let i = 0; i < messages.length - 1; i++) {
            if (messages[i].role === 'user' && messages[i + 1].role === 'assistant') {
                const facts = await this.extractFromConversation(
                    userId,
                    messages[i].content,
                    messages[i + 1].content,
                    options
                );
                allFacts.push(...facts);
            }
        }

        return allFacts;
    }
}

export const gituMemoryExtractor = new GituMemoryExtractor();
export default gituMemoryExtractor;
