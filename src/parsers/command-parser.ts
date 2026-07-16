export function parseCommandInput(input: string): string | undefined {
  if (!input) {
    return undefined;
  }
  
  // Trim and remove any leading slash commands if it's from chat, e.g., "/feature PROJ-123"
  // but usually the VS Code chat participant framework strips the slash command 
  // from the prompt, so `input` might just be "PROJ-123".
  // However, we handle it just in case.
  let cleaned = input.trim();
  
  if (cleaned.startsWith('/')) {
    const parts = cleaned.split(/\s+/);
    // Remove the first part (e.g., /feature)
    parts.shift();
    cleaned = parts.join(' ');
  }
  
  if (cleaned.length === 0) {
    return undefined;
  }
  
  return cleaned;
}
