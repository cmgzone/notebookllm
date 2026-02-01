import { z } from 'zod';
import yaml from 'yaml';

/**
 * Gitu Plugin Manifest Specification (v1)
 * Defines the structure of plugin.yaml
 */

export const PluginPermissionsSchema = z.object({
  network: z.boolean().default(false),
  filesystem: z.enum(['none', 'read-only', 'read-write']).default('none'),
  env: z.array(z.string()).default([]), // Allowed environment variables
});

export const PluginManifestSchema = z.object({
  name: z.string().min(3).max(50).regex(/^[a-z0-9_-]+$/),
  version: z.string().default('1.0.0'),
  description: z.string().max(200).optional(),
  runtime: z.enum(['node18', 'python3.11']),
  entry: z.string(),
  permissions: PluginPermissionsSchema.default({}),
  dependencies: z.record(z.string()).optional(), // e.g. { "axios": "^1.0.0" }
});

export type PluginManifest = z.infer<typeof PluginManifestSchema>;
export type PluginPermissions = z.infer<typeof PluginPermissionsSchema>;

export class PluginManifestParser {
  /**
   * Parse and validate a plugin.yaml content
   */
  static parse(yamlContent: string): PluginManifest {
    try {
      const parsed = yaml.parse(yamlContent);
      return PluginManifestSchema.parse(parsed);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        throw new Error(`Invalid plugin manifest: ${error.errors.map(e => `${e.path.join('.')}: ${e.message}`).join(', ')}`);
      }
      throw new Error(`Failed to parse plugin YAML: ${error.message}`);
    }
  }

  /**
   * Validate if a file path is a valid entry point
   */
  static isValidEntryPoint(entry: string, runtime: PluginManifest['runtime']): boolean {
    if (runtime === 'node18' && !entry.endsWith('.js')) return false;
    if (runtime === 'python3.11' && !entry.endsWith('.py')) return false;
    return true;
  }
}
