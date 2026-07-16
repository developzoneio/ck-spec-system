import * as vscode from 'vscode';
import { execSync } from 'child_process';
import { DiffContentProvider } from './tools/diff-content-provider';
import { ReviewerAgent } from './agents';
import { registerWorkflowCommands } from './commands/workflow-commands';
import { registerChatParticipant } from './chat/chat-participant';
import { registerDiffCommands } from './commands/diff-commands';
import { registerQuickFixCommands } from './commands/quick-fix-commands';
import { ReviewerCodeActionProvider } from './providers/reviewer-code-action-provider';

export function activate(context: vscode.ExtensionContext) {
  console.log('Hello Antigravity');
  registerWorkflowCommands(context);
  registerChatParticipant(context);
  registerDiffCommands(context);
  registerQuickFixCommands(context);

  context.subscriptions.push(
    vscode.languages.registerCodeActionsProvider(
      { scheme: 'file' },
      new ReviewerCodeActionProvider(),
      { providedCodeActionKinds: ReviewerCodeActionProvider.providedCodeActionKinds }
    )
  );

  const diffProvider = new DiffContentProvider();
  
  context.subscriptions.push(
    vscode.workspace.registerTextDocumentContentProvider('specwright-diff', diffProvider)
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('specwright.updateVirtualDoc', (uri: vscode.Uri, content: string) => {
      diffProvider.setContent(uri, content);
    })
  );

  const reviewerDiagnostics = vscode.languages.createDiagnosticCollection('sd-reviewer');
  context.subscriptions.push(reviewerDiagnostics);

  context.subscriptions.push(
    vscode.commands.registerCommand('specwright.runReviewer', async (diffCode?: string, specContent?: string) => {
      const apiKey = process.env.GEMINI_API_KEY || vscode.workspace.getConfiguration('specwright').get<string>('apiKey');
      if (!apiKey) {
        vscode.window.showErrorMessage('Gemini API Key is not configured. Please set GEMINI_API_KEY environment variable or configure it in settings.');
        return;
      }

      let diffToReview = diffCode;
      if (!diffToReview) {
        try {
          const workspaceFolders = vscode.workspace.workspaceFolders;
          if (workspaceFolders && workspaceFolders.length > 0) {
            const rootPath = workspaceFolders[0].uri.fsPath;
            diffToReview = execSync('git diff HEAD', { cwd: rootPath, encoding: 'utf8' });
          }
        } catch (e: any) {
          vscode.window.showErrorMessage('Failed to get git diff: ' + e.message);
          return;
        }
      }

      if (!diffToReview || diffToReview.trim() === '') {
        vscode.window.showInformationMessage('No diff detected to review.');
        return;
      }

      await vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: "Specwright: Reviewing code changes...",
        cancellable: false
      }, async () => {
        try {
          const agent = new ReviewerAgent({ apiKey });
          const reviewOutput = await agent.run(diffToReview!, specContent);

          reviewerDiagnostics.clear();

          const workspaceFolders = vscode.workspace.workspaceFolders;
          if (!workspaceFolders || workspaceFolders.length === 0) {
            return;
          }
          const rootUri = workspaceFolders[0].uri;
          const diagnosticMap = new Map<string, vscode.Diagnostic[]>();

          for (const comment of reviewOutput.comments) {
            const fileUri = vscode.Uri.joinPath(rootUri, comment.file);
            const absolutePath = fileUri.toString();

            const lineNum = Math.max(0, comment.line - 1);
            const range = new vscode.Range(lineNum, 0, lineNum, 1000);

            let severity: vscode.DiagnosticSeverity;
            switch (comment.severity) {
              case 'BLOCK':
                severity = vscode.DiagnosticSeverity.Error;
                break;
              case 'WARN':
                severity = vscode.DiagnosticSeverity.Warning;
                break;
              case 'SUGGEST':
                severity = vscode.DiagnosticSeverity.Information;
                break;
              default:
                severity = vscode.DiagnosticSeverity.Information;
            }

            const diagnostic = new vscode.Diagnostic(range, comment.comment, severity);
            diagnostic.source = 'specwright-reviewer';

            if (!diagnosticMap.has(absolutePath)) {
              diagnosticMap.set(absolutePath, []);
            }
            diagnosticMap.get(absolutePath)!.push(diagnostic);
          }

          for (const [uriStr, diagnostics] of diagnosticMap.entries()) {
            reviewerDiagnostics.set(vscode.Uri.parse(uriStr), diagnostics);
          }

          vscode.window.showInformationMessage(`Specwright Review completed. Found ${reviewOutput.comments.length} issues.`);
        } catch (e: any) {
          vscode.window.showErrorMessage('Reviewer Agent failed: ' + e.message);
        }
      });
    })
  );

  const disposable = vscode.commands.registerCommand('specwright.hello', () => {
    vscode.window.showInformationMessage('Hello Antigravity');
    console.log('Hello Antigravity');
  });

  context.subscriptions.push(disposable);
}

export function deactivate() {
  // Intentionally empty
}
