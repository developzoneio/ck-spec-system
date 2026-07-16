import * as vscode from 'vscode';

export class DiffContentProvider implements vscode.TextDocumentContentProvider {
  private contents = new Map<string, string>();
  private _onDidChange = new vscode.EventEmitter<vscode.Uri>();
  readonly onDidChange = this._onDidChange.event;

  public setContent(uri: vscode.Uri, content: string): void {
    this.contents.set(uri.toString(), content);
    this._onDidChange.fire(uri);
  }

  public provideTextDocumentContent(uri: vscode.Uri): string {
    return this.contents.get(uri.toString()) || '';
  }

  public removeContent(uri: vscode.Uri): void {
    this.contents.delete(uri.toString());
  }

  public dispose(): void {
    this.contents.clear();
    this._onDidChange.dispose();
  }
}
