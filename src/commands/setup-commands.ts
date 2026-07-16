import * as vscode from 'vscode';
import { SetupScaffolder } from '../tools/setup-scaffolder';
import { SetupFormPanel } from '../ui/setup-form-panel';

export function registerSetupCommands(context: vscode.ExtensionContext) {
  const setupCommand = vscode.commands.registerCommand('specwright.setup', async () => {
    const workspaceFolders = vscode.workspace.workspaceFolders;
    if (!workspaceFolders || workspaceFolders.length === 0) {
      vscode.window.showErrorMessage('Specwright: No workspace folder open. Please open a project first.');
      return;
    }

    const workspaceRoot = workspaceFolders[0].uri.fsPath;

    // Detect workspace state for idempotent behavior
    const state = SetupScaffolder.detectWorkspaceState(workspaceRoot);

    if (state === 'complete') {
      const choice = await vscode.window.showInformationMessage(
        'Specwright: This project is already set up. Would you like to review or update the configuration?',
        'Open Setup Form',
        'Cancel'
      );

      if (choice !== 'Open Setup Form') {
        return;
      }
    }

    // Show the setup form webview
    SetupFormPanel.show(context, state, workspaceRoot);
  });

  context.subscriptions.push(setupCommand);
}
