/**
 * MCP User Settings Service
 * Manages user-specific MCP settings like code analysis model preference
 */

import pool from '../config/database.js';

export interface McpUserSettings {
  id: string;
  userId: string;
  codeAnalysisModelId: string | null;
  codeAnalysisEnabled: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface UpdateMcpUserSettingsParams {
  codeAnalysisModelId?: string | null;
  codeAnalysisEnabled?: boolean;
}

class McpUserSettingsService {
  /**
   * Get user's MCP settings, creating default if not exists
   */
  async getSettings(userId: string): Promise<McpUserSettings> {
    // Try to get existing settings
    const result = await pool.query(
      `SELECT id, user_id, code_analysis_model_id, code_analysis_enabled, created_at, updated_at
       FROM mcp_user_settings
       WHERE user_id = $1`,
      [userId]
    );
    
    if (result.rows.length > 0) {
      return this.mapSettings(result.rows[0]);
    }
    
    // Create default settings
    const insertResult = await pool.query(
      `INSERT INTO mcp_user_settings (user_id, code_analysis_enabled)
       VALUES ($1, true)
       RETURNING id, user_id, code_analysis_model_id, code_analysis_enabled, created_at, updated_at`,
      [userId]
    );
    
    return this.mapSettings(insertResult.rows[0]);
  }

  /**
   * Update user's MCP settings
   */
  async updateSettings(userId: string, params: UpdateMcpUserSettingsParams): Promise<McpUserSettings> {
    // Ensure settings exist
    await this.getSettings(userId);
    
    const updates: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;
    
    if (params.codeAnalysisModelId !== undefined) {
      updates.push(`code_analysis_model_id = $${paramIndex++}`);
      values.push(params.codeAnalysisModelId);
    }
    
    if (params.codeAnalysisEnabled !== undefined) {
      updates.push(`code_analysis_enabled = $${paramIndex++}`);
      values.push(params.codeAnalysisEnabled);
    }
    
    if (updates.length === 0) {
      return this.getSettings(userId);
    }
    
    updates.push(`updated_at = NOW()`);
    values.push(userId);
    
    const result = await pool.query(
      `UPDATE mcp_user_settings
       SET ${updates.join(', ')}
       WHERE user_id = $${paramIndex}
       RETURNING id, user_id, code_analysis_model_id, code_analysis_enabled, created_at, updated_at`,
      values
    );
    
    return this.mapSettings(result.rows[0]);
  }

  /**
   * Get the user's preferred code analysis model ID
   * Returns null if not set (will use default)
   */
  async getCodeAnalysisModelId(userId: string): Promise<string | null> {
    const settings = await this.getSettings(userId);
    return settings.codeAnalysisEnabled ? settings.codeAnalysisModelId : null;
  }

  /**
   * Check if code analysis is enabled for user
   */
  async isCodeAnalysisEnabled(userId: string): Promise<boolean> {
    const settings = await this.getSettings(userId);
    return settings.codeAnalysisEnabled;
  }

  /**
   * Get available AI models for code analysis
   */
  async getAvailableModels(): Promise<Array<{
    id: string;
    name: string;
    modelId: string;
    provider: string;
    description: string;
    isPremium: boolean;
  }>> {
    const result = await pool.query(
      `SELECT id, name, model_id, provider, description, is_premium
       FROM ai_models
       WHERE is_active = true
       ORDER BY 
         CASE WHEN provider = 'gemini' THEN 0 ELSE 1 END,
         name`
    );
    
    return result.rows.map(row => ({
      id: row.id,
      name: row.name,
      modelId: row.model_id,
      provider: row.provider,
      description: row.description || '',
      isPremium: row.is_premium,
    }));
  }

  private mapSettings(row: any): McpUserSettings {
    return {
      id: row.id,
      userId: row.user_id,
      codeAnalysisModelId: row.code_analysis_model_id,
      codeAnalysisEnabled: row.code_analysis_enabled,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}

export const mcpUserSettingsService = new McpUserSettingsService();
export default mcpUserSettingsService;
