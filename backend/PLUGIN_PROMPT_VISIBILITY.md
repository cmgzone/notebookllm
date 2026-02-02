# Plugin Prompt Visibility

Gitu plugins can be enabled for execution but hidden from the AI model prompt to reduce prompt size and prevent automatic invocation.

## Behavior
- If a plugin has `config.disableModelInvocation = true`, it is excluded from the “User Plugins (Custom Tools)” section of the system prompt.
- The plugin remains runnable via `run_user_plugin`.

## Toggle
Use the MCP tool:
- `set_plugin_model_invocation` with:
  - `pluginId` or `pluginName`
  - `disableModelInvocation`: boolean

## Example
Hide a plugin from the model prompt:

```json
{
  "tool": "set_plugin_model_invocation",
  "args": {
    "pluginName": "Daily Report Generator",
    "disableModelInvocation": true
  }
}
```

