import * as vscode from 'vscode';
import { ImplementerAgent } from '../agents';
import { IdeToolHandlers } from '../tools/ide-tools.handlers';

export function registerDiffCommands(context: vscode.ExtensionContext) {
  const acceptCommand = vscode.commands.registerCommand('specwright.diff.accept', async () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
      vscode.window.showErrorMessage('No active diff editor.');
      return;
    }

    const document = editor.document;
    if (document.uri.scheme !== 'specwright-diff') {
      vscode.window.showErrorMessage('Active document is not a specwright diff.');
      return;
    }

    // URI is specwright-diff:/path/to/file or specwright-diff:c:/path/to/file
    // Let's get the original URI
    const originalPath = document.uri.path;
    const originalUri = vscode.Uri.file(originalPath);

    try {
      const content = new TextEncoder().encode(document.getText());
      await vscode.workspace.fs.writeFile(originalUri, content);
      
      vscode.window.showInformationMessage(`Changes accepted and saved to ${originalPath}`);
      
      // Close the diff viewer tab
      await vscode.commands.executeCommand('workbench.action.closeActiveEditor');
    } catch (e: any) {
      vscode.window.showErrorMessage(`Failed to save file: ${e.message}`);
    }
  });

  const rejectCommand = vscode.commands.registerCommand('specwright.diff.reject', async () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
      vscode.window.showErrorMessage('No active diff editor.');
      return;
    }

    const document = editor.document;
    if (document.uri.scheme !== 'specwright-diff') {
      vscode.window.showErrorMessage('Active document is not a specwright diff.');
      return;
    }

    const feedback = await vscode.window.showInputBox({
      prompt: 'Ask AI to Fix: Describe what needs to be changed',
      placeHolder: 'e.g., Use a different variable name, Fix the loop logic'
    });

    if (!feedback) {
      // User cancelled
      return;
    }

    const apiKey = process.env.GEMINI_API_KEY || vscode.workspace.getConfiguration('specwright').get<string>('apiKey');
    if (!apiKey) {
      vscode.window.showErrorMessage('Gemini API Key is not configured. Please set GEMINI_API_KEY environment variable or configure it in settings.');
      return;
    }

    const workspaceFolders = vscode.workspace.workspaceFolders;
    if (!workspaceFolders || workspaceFolders.length === 0) {
      vscode.window.showErrorMessage('No workspace folder open.');
      return;
    }

    const rootUri = workspaceFolders[0].uri;
    const originalPath = document.uri.path;
    const diffContent = document.getText();

    // Close the diff viewer tab
    await vscode.commands.executeCommand('workbench.action.closeActiveEditor');

    vscode.window.withProgress({
      location: vscode.ProgressLocation.Notification,
      title: 'Specwright: AI is fixing the file...',
      cancellable: false
    }, async () => {
      try {
        const toolHandlers = new IdeToolHandlers(rootUri);
        const agent = new ImplementerAgent({ apiKey }, toolHandlers);
        
        const taskPayload = `The user rejected the changes for the file ${originalPath}.\n\nFeedback from user:\n"${feedback}"\n\nCurrent proposed content was:\n\`\`\`\n${diffContent}\n\`\`\`\n\nPlease apply the necessary fixes.`;
        
        await agent.run(taskPayload);
        vscode.window.showInformationMessage('Specwright: Fix applied. Please review the new diff.');
      } catch (e: any) {
        vscode.window.showErrorMessage(`Failed to run ImplementerAgent: ${e.message}`);
      }
    });
  });

  context.subscriptions.push(acceptCommand, rejectCommand);
}
