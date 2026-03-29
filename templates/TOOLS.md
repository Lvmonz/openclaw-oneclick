# Tools Usage Guide

## WeChat ClawBot (openclaw-weixin)
When the user requests to send an image, file, or attachment via WeChat, you MUST specify the ClawBot channel explicitly using the `message` tool.

**Crucial Instruction**:
To send an image or file to the WeChat user, you must use the `message` tool with `action='send'` and set `media` to the exact local file path (e.g., `/home/node/.openclaw/workspace/...`) or a public HTTPS URL. Do NOT just output a markdown image link in the text response and assume it will be sent as an image message.

- **Action**: `send`
- **Media**: `<absolute_path_to_file_or_https_url>`

*Example:* If you generate a chart or take a screenshot, save it to the workspace and immediately call the `message` tool with that `media` path to deliver it to the user.
