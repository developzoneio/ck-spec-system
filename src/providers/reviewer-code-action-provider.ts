import * as vscode from 'vscode';

export class ReviewerCodeActionProvider implements vscode.CodeActionProvider {
  public static readonly providedCodeActionKinds = [
    vscode.CodeActionKind.QuickFix
  ];

  public provideCodeActions(
    document: vscode.TextDocument,
    range: vscode.Range | vscode.Selection,
    context: vscode.CodeActionContext,
    token: vscode.CancellationToken
  ): vscode.CodeAction[] | undefined {
    const reviewerDiagnostics = context.diagnostics.filter(diagnostic => diagnostic.source === 'specwright-reviewer');

    if (reviewerDiagnostics.length === 0) {
      return undefined;
    }

    const actions: vscode.CodeAction[] = [];

    for (const diagnostic of reviewerDiagnostics) {
      const fixAction = new vscode.CodeAction(`Auto-fix with Specwright AI`, vscode.CodeActionKind.QuickFix);
      fixAction.command = {
        command: 'specwright.fixReviewerIssue',
        title: 'Auto-fix with Specwright AI',
        arguments: [document, diagnostic]
      };
      fixAction.diagnostics = [diagnostic];
      fixAction.isPreferred = true;
      actions.push(fixAction);
    }

    return actions;
  }
}
