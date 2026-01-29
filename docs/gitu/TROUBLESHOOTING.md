# Gitu Troubleshooting Guide

Common issues and solutions for using Gitu Universal Assistant.

## Connection Issues

### "Authentication Required" (401 Error)
**Symptom**: You see a "401 Unauthorized" error or "Access token required".
**Cause**: Your session has expired or the authentication token is missing.
**Solution**:
1. Log out and log back in to the NotebookLLM app.
2. If using the Terminal CLI, run `gitu auth refresh` or re-authenticate with `gitu auth --qr`.

### WebSocket Disconnection
**Symptom**: Chat status stays on "Connecting..." or shows "Offline".
**Solution**:
1. Check your internet connection.
2. Verify that the backend server is running (if self-hosting).
3. Restart the app.

## Terminal CLI

### "User not found"
**Cause**: The user ID associated with your token does not exist.
**Solution**: Ensure you are using a token generated from a valid account. Try generating a new token in the app.

### QR Code Scanning Fails
**Solution**:
1. Ensure your terminal window is large enough to display the full QR code.
2. Increase the brightness of your screen.
3. Use the Pairing Token method (`gitu auth <token>`) instead.

## Telegram Bot

### Bot Not Responding
**Solution**:
1. Type `/start` to restart the bot interaction.
2. If that fails, try `/clear` to reset the conversation history.

### "Account not linked"
**Solution**:
1. Go to **NotebookLLM App > Settings > Integrations**.
2. Select **Telegram** and follow the linking instructions.
3. Once linked, try chatting with the bot again.

## Deep Research

### "Research Failed" or Stuck
**Solution**:
1. Deep research requires significant processing time. Ensure you wait at least 2-3 minutes.
2. Check your credit/quota balance in the app settings.
3. Retry the request with a more specific query.

## Support
If you continue to experience issues, please contact support or file an issue in the GitHub repository.
