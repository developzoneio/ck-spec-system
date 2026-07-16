import * as vscode from 'vscode';
import { ImplementerAgent } from '../agents';
import { IdeToolHandlers } from '../tools/ide-tools.handlers';

export function registerQuickFixCommands(context: vscode.ExtensionContext) {
  const fixReviewerIssueCommand = vscode.commands.registerCommand(
    'specwright.fixReviewerIssue',
    async (document: vscode.TextDocument, diagnostic: vscode.Diagnostic) => {
      const apiKey = process.env.GEMINI_API_KEY || vscode.workspace.getConfiguration('specwright').get<string>('apiKey');
      if (!apiKey) {
        vscode.window.showErrorMessage('Gemini API Key is not configured. Please set GEMINI_API_KEY environment variable or configure it in settings.');
        return;
      }

      const workspaceFolders = vscode.workspace.workspaceFolders;
      if (!workspaceFolders || workspaceFolders.length === 0) {
        vscode.window.showErrorMessage('Specwright: No workspace folder open.');
        return;
      }

      const rootUri = workspaceFolders[0].uri;
      const relativePath = vscode.workspace.asRelativePath(document.uri, false);
      const lineNumber = diagnostic.range.start.line + 1;
      const issueMessage = diagnostic.message;

      await vscode.window.withProgress(
        {
          location: vscode.ProgressLocation.Notification,
          title: `Specwright: Auto-fixing issue in ${relativePath}...`,
          cancellable: false
        },
        async () => {
          try {
            const toolHandlers = new IdeToolHandlers(rootUri);
            const agent = new ImplementerAgent({ apiKey }, toolHandlers);

            const taskPayload = `A code review issue was found in file: ${relativePath}
Line Number: ${lineNumber}
Issue Description: ${issueMessage}

Please analyze the file, identify the problem, and use your IDE tools (like ide_apply_diff) to implement a fix for this specific issue.`;

            await agent.run(taskPayload);
            vscode.window.showInformationMessage(`Specwright: AI finished applying the fix for ${relativePath}. Please review the diff.`);
          } catch (error: any) {
            vscode.window.showErrorMessage(`Specwright: Failed to apply fix: ${error.message}`);
          }
        }
      );
    }
  );

  context.subscriptions.push(fixReviewerIssueCommand);
}
