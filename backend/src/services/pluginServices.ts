import { dockerPluginRunner } from './plugins/dockerPluginRunner.js';
import { PluginManifestParser } from './plugins/pluginManifest.js';

export * from './plugins/pluginManifest.js';
export * from './plugins/dockerPluginRunner.js';

export const pluginServices = {
  dockerRunner: dockerPluginRunner,
  manifestParser: PluginManifestParser
};
