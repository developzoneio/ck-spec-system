import * as vscode from 'vscode';

export function activate(context: vscode.ExtensionContext) {
  console.log('Hello Antigravity');

  const disposable = vscode.commands.registerCommand('specwright.hello', () => {
    vscode.window.showInformationMessage('Hello Antigravity');
    console.log('Hello Antigravity');
  });

  context.subscriptions.push(disposable);
}

export function deactivate() {
  // Intentionally empty
}
