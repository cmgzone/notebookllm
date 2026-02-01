Based on the user's detailed architectural request and my analysis of the current system, I propose the following plan to implement the **Secure Plugin Architecture**.

The current system has a basic `vm`-based plugin system and a `gituShellManager` that supports Docker. The user's request is to upgrade this to a full **container-per-plugin** model with a formal manifest (`plugin.yaml`) and dependency management.

I will start with the **Plugin Spec (v1)** and the **Plugin Runner Service**.

## Phase 1: Define Plugin Spec & Manifest Logic
1.  **Create `PluginManifest` Interface**: Define the structure for `plugin.yaml` (name, runtime, entry, permissions).
2.  **Create `PluginPackageService`**:
    *   Logic to parse `plugin.yaml`.
    *   Logic to validate permissions against the manifest.
    *   Logic to detect runtime (Node.js, Python).

## Phase 2: Implement Containerized Plugin Runner
1.  **Create `PluginContainerRunner`**:
    *   **Image Construction**: Implement "Strategy B" (Build plugin image) as requested.
        *   Generate a dynamic `Dockerfile` based on the runtime (e.g., `FROM python:3.11-slim`).
        *   Copy plugin files.
        *   Run dependency installation (`pip install`, `npm install`) *inside* the build process.
    *   **Execution**: Use Docker to run the built image.
        *   Apply resource limits (CPU, Memory) as requested.
        *   Enforce network isolation based on manifest permissions.
        *   Mount necessary volumes (if filesystem permission is granted).

## Phase 3: Integrate with Agent Swarm
1.  **Update `GituAgentManager`**:
    *   Allow agents to "load" these new containerized plugins.
    *   When an agent calls a tool that maps to a plugin, route it through the `PluginContainerRunner`.

## Immediate Action Items (This Session)
I will focus on **Phase 1 and Phase 2 (Foundation)**:

1.  **Create `backend/src/services/plugins/pluginManifest.ts`**: Define the `PluginManifest` type and validation logic.
2.  **Create `backend/src/services/plugins/dockerPluginRunner.ts`**: Implement the Docker runner service that handles:
    *   Building the plugin image (generating Dockerfile).
    *   Running the container with `docker run` and strict flags.

This directly addresses the user's "Final Recommendation" to run everything in Docker with a permission manifest.
