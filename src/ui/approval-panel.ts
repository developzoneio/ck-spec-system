import * as vscode from 'vscode';
import { StateMachine } from '../orchestrator/StateMachine';
import { WorkflowEvent } from '../orchestrator/WorkflowContext';

export class ApprovalPanel {
  public static currentPanel: ApprovalPanel | undefined;
  private readonly _panel: vscode.WebviewPanel;
  private _disposables: vscode.Disposable[] = [];

  private constructor(
    panel: vscode.WebviewPanel,
    private readonly stateMachine: StateMachine,
    private readonly documentUri: vscode.Uri
  ) {
    this._panel = panel;

    this._panel.webview.html = this._getHtmlForWebview();

    this._panel.onDidDispose(() => this.dispose(), null, this._disposables);

    this._panel.webview.onDidReceiveMessage(
      async (message) => {
        switch (message.command) {
          case 'approve':
            await this.handleApprove();
            break;
          case 'reject':
            await this.handleReject();
            break;
          case 'cancel':
            this.dispose();
            break;
        }
      },
      null,
      this._disposables
    );
  }

  public static show(context: vscode.ExtensionContext, documentPath: string, stateMachine: StateMachine) {
    const documentUri = vscode.Uri.file(documentPath);

    // If we already have a panel, show it.
    if (ApprovalPanel.currentPanel) {
      ApprovalPanel.currentPanel._panel.reveal(vscode.ViewColumn.One);
    } else {
      // Otherwise, create a new panel.
      const panel = vscode.window.createWebviewPanel(
        'specwrightApproval',
        'Specwright: Review',
        vscode.ViewColumn.One,
        {
          enableScripts: true,
          retainContextWhenHidden: true,
        }
      );

      ApprovalPanel.currentPanel = new ApprovalPanel(panel, stateMachine, documentUri);
    }

    // Open the text document in ViewColumn.Two
    vscode.workspace.openTextDocument(documentUri).then(doc => {
      vscode.window.showTextDocument(doc, {
        viewColumn: vscode.ViewColumn.Two,
        preserveFocus: true,
        preview: false
      });
    }, (error) => {
      vscode.window.showErrorMessage(`Failed to open document: ${error.message}`);
    });
  }

  private async handleApprove() {
    // Check if document is open and save if dirty
    const doc = vscode.workspace.textDocuments.find(d => d.uri.toString() === this.documentUri.toString());
    if (doc && doc.isDirty) {
      await doc.save();
    }
    
    this.stateMachine.dispatch(WorkflowEvent.USER_APPROVED);
    this.dispose();
  }

  private async handleReject() {
    const reason = await vscode.window.showInputBox({
      title: 'Reject & Revise',
      prompt: 'Please enter the reason for rejection',
      ignoreFocusOut: true,
    });

    if (reason !== undefined) {
      this.stateMachine.dispatch(WorkflowEvent.USER_REJECTED, { rejectionReason: reason });
      this.dispose();
    }
  }

  public dispose() {
    ApprovalPanel.currentPanel = undefined;

    this._panel.dispose();

    while (this._disposables.length) {
      const x = this._disposables.pop();
      if (x) {
        x.dispose();
      }
    }
  }

  private _getHtmlForWebview() {
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Specwright Approval</title>
    <style>
        body {
            font-family: var(--vscode-font-family);
            padding: 20px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background-color: var(--vscode-editor-background);
            color: var(--vscode-editor-foreground);
        }
        .container {
            text-align: center;
            max-width: 400px;
        }
        h2 {
            margin-bottom: 10px;
            color: var(--vscode-editor-foreground);
        }
        p {
            margin-bottom: 30px;
            color: var(--vscode-descriptionForeground);
            line-height: 1.5;
        }
        .button-group {
            display: flex;
            flex-direction: column;
            gap: 15px;
        }
        button {
            border: none;
            padding: 12px 20px;
            font-size: 14px;
            font-weight: 600;
            border-radius: 4px;
            cursor: pointer;
            transition: background-color 0.2s ease, transform 0.1s ease;
            width: 100%;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        button:active {
            transform: scale(0.98);
        }
        .btn-approve {
            background-color: var(--vscode-button-background);
            color: var(--vscode-button-foreground);
        }
        .btn-approve:hover {
            background-color: var(--vscode-button-hoverBackground);
        }
        .btn-reject {
            background-color: var(--vscode-errorForeground);
            color: var(--vscode-button-foreground);
        }
        .btn-reject:hover {
            opacity: 0.9;
        }
        .btn-cancel {
            background-color: transparent;
            border: 1px solid var(--vscode-button-secondaryBackground);
            color: var(--vscode-foreground);
        }
        .btn-cancel:hover {
            background-color: var(--vscode-button-secondaryBackground);
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>Review Generated Document</h2>
        <p>The AI Agent has completed drafting the document. Please review it in the editor on the right. You can edit the text directly before approving.</p>
        
        <div class="button-group">
            <button class="btn-approve" onclick="sendCommand('approve')">
                <svg style="width:16px;height:16px;margin-right:8px" viewBox="0 0 24 24">
                    <path fill="currentColor" d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/>
                </svg>
                Approve & Continue
            </button>
            <button class="btn-reject" onclick="sendCommand('reject')">
                <svg style="width:16px;height:16px;margin-right:8px" viewBox="0 0 24 24">
                    <path fill="currentColor" d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/>
                </svg>
                Reject & Revise
            </button>
            <button class="btn-cancel" onclick="sendCommand('cancel')">Cancel</button>
        </div>
    </div>

    <script>
        const vscode = acquireVsCodeApi();
        
        function sendCommand(command) {
            vscode.postMessage({ command: command });
        }
    </script>
</body>
</html>`;
  }
}
