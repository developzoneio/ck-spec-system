import * as vscode from 'vscode';
import { SetupFormData, WorkspaceState } from '../schemas/setup-form-data';
import { SetupOrchestrator } from '../orchestrator/setup-orchestrator';

export class SetupFormPanel {
  public static currentPanel: SetupFormPanel | undefined;
  private readonly _panel: vscode.WebviewPanel;
  private _disposables: vscode.Disposable[] = [];

  private constructor(
    panel: vscode.WebviewPanel,
    private readonly context: vscode.ExtensionContext,
    private readonly workspaceState: WorkspaceState,
    private readonly workspaceRoot: string
  ) {
    this._panel = panel;

    this._panel.webview.html = this._getHtmlForWebview();

    this._panel.onDidDispose(() => this.dispose(), null, this._disposables);

    this._panel.webview.onDidReceiveMessage(
      async (message) => {
        switch (message.command) {
          case 'submit':
            await this.handleSubmit(message.data as SetupFormData);
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

  public static show(
    context: vscode.ExtensionContext,
    workspaceState: WorkspaceState,
    workspaceRoot: string
  ) {
    // If we already have a panel, reveal it
    if (SetupFormPanel.currentPanel) {
      SetupFormPanel.currentPanel._panel.reveal(vscode.ViewColumn.One);
      return;
    }

    const panel = vscode.window.createWebviewPanel(
      'specwrightSetup',
      'Specwright: Project Setup',
      vscode.ViewColumn.One,
      {
        enableScripts: true,
        retainContextWhenHidden: true,
      }
    );

    SetupFormPanel.currentPanel = new SetupFormPanel(panel, context, workspaceState, workspaceRoot);
  }

  private async handleSubmit(formData: SetupFormData) {
    // Show progress in the webview
    this._panel.webview.postMessage({ command: 'showProgress', message: 'Generating constitution with AI...' });

    try {
      const orchestrator = new SetupOrchestrator(this.context);
      const result = await orchestrator.run(formData, this.workspaceRoot);

      if (result.success) {
        this._panel.webview.postMessage({
          command: 'showResult',
          success: true,
          data: result,
        });

        vscode.window.showInformationMessage(
          `Specwright: Setup complete! ${result.filesCreated.length} files created.`
        );
      } else {
        this._panel.webview.postMessage({
          command: 'showResult',
          success: false,
          data: result,
        });

        vscode.window.showErrorMessage(`Specwright: Setup failed — ${result.message}`);
      }
    } catch (error: any) {
      this._panel.webview.postMessage({
        command: 'showResult',
        success: false,
        data: { message: error.message },
      });

      vscode.window.showErrorMessage(`Specwright: Setup failed — ${error.message}`);
    }
  }

  public dispose() {
    SetupFormPanel.currentPanel = undefined;

    this._panel.dispose();

    while (this._disposables.length) {
      const x = this._disposables.pop();
      if (x) {
        x.dispose();
      }
    }
  }

  private _getProjectNameDefault(): string {
    const folderName = this.workspaceRoot.split(/[\\/]/).pop() || 'my-project';
    return folderName;
  }

  private _getHtmlForWebview() {
    const projectName = this._getProjectNameDefault();
    const isUpdate = this.workspaceState !== 'fresh';
    const stateLabel = this.workspaceState === 'fresh'
      ? 'New Project'
      : this.workspaceState === 'partial'
        ? 'Partial Setup Detected'
        : 'Existing Setup Detected';

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Specwright: Project Setup</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        body {
            font-family: var(--vscode-font-family);
            background-color: var(--vscode-editor-background);
            color: var(--vscode-editor-foreground);
            padding: 0;
            margin: 0;
            min-height: 100vh;
            display: flex;
            justify-content: center;
        }
        .container {
            max-width: 640px;
            width: 100%;
            padding: 32px 24px;
        }

        /* Header */
        .header {
            margin-bottom: 28px;
        }
        .header h1 {
            font-size: 22px;
            font-weight: 600;
            margin-bottom: 6px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .header h1 .icon {
            font-size: 24px;
        }
        .header .subtitle {
            font-size: 13px;
            color: var(--vscode-descriptionForeground);
            line-height: 1.5;
        }
        .state-badge {
            display: inline-block;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            padding: 3px 10px;
            border-radius: 12px;
            margin-top: 8px;
            background-color: var(--vscode-badge-background);
            color: var(--vscode-badge-foreground);
        }
        .state-badge.update {
            background-color: var(--vscode-editorWarning-foreground);
            color: var(--vscode-editor-background);
        }

        /* Form groups */
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            font-size: 13px;
            font-weight: 600;
            margin-bottom: 6px;
            color: var(--vscode-editor-foreground);
        }
        label .hint {
            font-weight: 400;
            font-size: 12px;
            color: var(--vscode-descriptionForeground);
            margin-left: 4px;
        }
        input[type="text"],
        select,
        textarea {
            width: 100%;
            padding: 8px 12px;
            font-size: 13px;
            font-family: var(--vscode-font-family);
            background-color: var(--vscode-input-background);
            color: var(--vscode-input-foreground);
            border: 1px solid var(--vscode-input-border, transparent);
            border-radius: 4px;
            outline: none;
            transition: border-color 0.15s ease;
        }
        input[type="text"]:focus,
        select:focus,
        textarea:focus {
            border-color: var(--vscode-focusBorder);
        }
        textarea {
            resize: vertical;
            min-height: 100px;
            line-height: 1.5;
        }
        select {
            cursor: pointer;
        }

        /* Two-column row */
        .row {
            display: flex;
            gap: 16px;
        }
        .row .form-group {
            flex: 1;
        }

        /* Divider */
        .divider {
            border: none;
            border-top: 1px solid var(--vscode-widget-border, var(--vscode-panel-border, rgba(128,128,128,0.2)));
            margin: 24px 0;
        }

        /* Button row */
        .button-row {
            display: flex;
            gap: 12px;
            margin-top: 28px;
        }
        button {
            border: none;
            padding: 10px 20px;
            font-size: 13px;
            font-weight: 600;
            font-family: var(--vscode-font-family);
            border-radius: 4px;
            cursor: pointer;
            transition: background-color 0.15s ease, opacity 0.15s ease;
        }
        button:active {
            transform: scale(0.98);
        }
        .btn-primary {
            background-color: var(--vscode-button-background);
            color: var(--vscode-button-foreground);
            flex: 1;
        }
        .btn-primary:hover {
            background-color: var(--vscode-button-hoverBackground);
        }
        .btn-primary:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
        .btn-secondary {
            background-color: transparent;
            border: 1px solid var(--vscode-button-secondaryBackground);
            color: var(--vscode-foreground);
        }
        .btn-secondary:hover {
            background-color: var(--vscode-button-secondaryBackground);
        }

        /* Progress overlay */
        .progress-overlay {
            display: none;
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background-color: rgba(0, 0, 0, 0.5);
            justify-content: center;
            align-items: center;
            z-index: 100;
        }
        .progress-overlay.visible {
            display: flex;
        }
        .progress-card {
            background-color: var(--vscode-editor-background);
            border: 1px solid var(--vscode-widget-border, rgba(128,128,128,0.3));
            border-radius: 8px;
            padding: 32px 40px;
            text-align: center;
            max-width: 360px;
        }
        .progress-card .spinner {
            width: 32px;
            height: 32px;
            border: 3px solid var(--vscode-descriptionForeground);
            border-top-color: var(--vscode-button-background);
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
            margin: 0 auto 16px;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        .progress-card p {
            font-size: 13px;
            color: var(--vscode-descriptionForeground);
        }

        /* Result overlay */
        .result-overlay {
            display: none;
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background-color: rgba(0, 0, 0, 0.5);
            justify-content: center;
            align-items: center;
            z-index: 100;
        }
        .result-overlay.visible {
            display: flex;
        }
        .result-card {
            background-color: var(--vscode-editor-background);
            border: 1px solid var(--vscode-widget-border, rgba(128,128,128,0.3));
            border-radius: 8px;
            padding: 28px 36px;
            max-width: 440px;
            width: 90%;
        }
        .result-card h3 {
            font-size: 16px;
            margin-bottom: 12px;
        }
        .result-card .file-list {
            list-style: none;
            padding: 0;
            margin: 12px 0;
            font-size: 12px;
            font-family: var(--vscode-editor-font-family, monospace);
        }
        .result-card .file-list li {
            padding: 3px 0;
            color: var(--vscode-descriptionForeground);
        }
        .result-card .file-list li::before {
            content: "✓ ";
            color: var(--vscode-charts-green, #3fb950);
        }
        .result-card .file-list li.skipped::before {
            content: "⊘ ";
            color: var(--vscode-descriptionForeground);
        }
        .result-card button {
            margin-top: 16px;
            width: 100%;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><span class="icon">⚙️</span> Project Setup</h1>
            <p class="subtitle">Configure your project for Specwright spec-driven development. The AI will generate a personalized <code>GEMINI_CONSTITUTION.md</code> and scaffold the <code>.specs/</code> directory.</p>
            <span class="state-badge ${isUpdate ? 'update' : ''}">${stateLabel}</span>
            ${isUpdate ? '<p class="subtitle" style="margin-top:8px">Existing files will not be overwritten. Only missing files will be created.</p>' : ''}
        </div>

        <form id="setupForm">
            <!-- Project name -->
            <div class="form-group">
                <label for="projectName">Project Name</label>
                <input type="text" id="projectName" value="${projectName}" required />
            </div>

            <hr class="divider" />

            <!-- Tech Stack -->
            <div class="row">
                <div class="form-group">
                    <label for="language">Language</label>
                    <select id="language">
                        <option value="TypeScript">TypeScript</option>
                        <option value="JavaScript">JavaScript</option>
                        <option value="Python">Python</option>
                        <option value="C#/.NET">C# / .NET</option>
                        <option value="Java">Java</option>
                        <option value="Go">Go</option>
                        <option value="Rust">Rust</option>
                        <option value="Other">Other</option>
                    </select>
                </div>
                <div class="form-group">
                    <label for="framework">Framework <span class="hint">(optional)</span></label>
                    <input type="text" id="framework" placeholder="e.g. Next.js, FastAPI, ASP.NET" />
                </div>
            </div>

            <div class="form-group">
                <label for="database">Database <span class="hint">(optional)</span></label>
                <input type="text" id="database" placeholder="e.g. PostgreSQL, MongoDB, SQL Server" />
            </div>

            <hr class="divider" />

            <!-- Team rules -->
            <div class="form-group">
                <label for="teamRules">Team-Specific Rules & Conventions</label>
                <textarea id="teamRules" placeholder="Enter any coding conventions, architectural rules, or forbidden patterns specific to your team. These will be incorporated into the generated constitution.&#10;&#10;Examples:&#10;- Use == false instead of ! for negation&#10;- Custom domain exceptions, never generic Exception&#10;- DTOs cross layer boundaries; entities never leave the domain"></textarea>
            </div>

            <hr class="divider" />

            <!-- Shell -->
            <div class="form-group">
                <label for="shell">Development Shell</label>
                <select id="shell">
                    <option value="powershell">PowerShell (Windows)</option>
                    <option value="bash">Bash / Zsh (Unix / macOS)</option>
                    <option value="both">Both</option>
                </select>
            </div>

            <!-- Buttons -->
            <div class="button-row">
                <button type="button" class="btn-secondary" onclick="cancel()">Cancel</button>
                <button type="submit" class="btn-primary" id="submitBtn">
                    <svg style="width:14px;height:14px;margin-right:6px;vertical-align:middle" viewBox="0 0 24 24">
                        <path fill="currentColor" d="M17.65 6.35A7.958 7.958 0 0 0 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08A5.99 5.99 0 0 1 12 18c-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z"/>
                    </svg>
                    Generate & Scaffold
                </button>
            </div>
        </form>
    </div>

    <!-- Progress overlay -->
    <div class="progress-overlay" id="progressOverlay">
        <div class="progress-card">
            <div class="spinner"></div>
            <p id="progressMessage">Generating constitution with AI...</p>
        </div>
    </div>

    <!-- Result overlay -->
    <div class="result-overlay" id="resultOverlay">
        <div class="result-card" id="resultCard">
            <!-- Filled dynamically -->
        </div>
    </div>

    <script>
        const vscode = acquireVsCodeApi();

        document.getElementById('setupForm').addEventListener('submit', (e) => {
            e.preventDefault();

            const data = {
                projectName: document.getElementById('projectName').value.trim(),
                language: document.getElementById('language').value,
                framework: document.getElementById('framework').value.trim(),
                database: document.getElementById('database').value.trim() || undefined,
                teamRules: document.getElementById('teamRules').value.trim(),
                shell: document.getElementById('shell').value,
            };

            if (!data.projectName) {
                return;
            }

            document.getElementById('submitBtn').disabled = true;
            vscode.postMessage({ command: 'submit', data });
        });

        function cancel() {
            vscode.postMessage({ command: 'cancel' });
        }

        window.addEventListener('message', (event) => {
            const msg = event.data;
            switch (msg.command) {
                case 'showProgress':
                    document.getElementById('progressMessage').textContent = msg.message;
                    document.getElementById('progressOverlay').classList.add('visible');
                    break;

                case 'showResult':
                    document.getElementById('progressOverlay').classList.remove('visible');
                    const card = document.getElementById('resultCard');
                    const d = msg.data;

                    if (msg.success) {
                        let filesHtml = '';
                        if (d.filesCreated && d.filesCreated.length > 0) {
                            filesHtml += '<ul class="file-list">';
                            d.filesCreated.forEach(f => { filesHtml += '<li>' + f + '</li>'; });
                            filesHtml += '</ul>';
                        }
                        if (d.filesSkipped && d.filesSkipped.length > 0) {
                            filesHtml += '<p style="font-size:12px;color:var(--vscode-descriptionForeground);margin-top:8px">Skipped (already exist):</p>';
                            filesHtml += '<ul class="file-list">';
                            d.filesSkipped.forEach(f => { filesHtml += '<li class="skipped">' + f + '</li>'; });
                            filesHtml += '</ul>';
                        }

                        card.innerHTML =
                            '<h3 style="color:var(--vscode-charts-green, #3fb950)">✓ Setup Complete</h3>' +
                            '<p style="font-size:13px;color:var(--vscode-descriptionForeground)">' + d.message + '</p>' +
                            filesHtml +
                            (d.placeholdersRemaining > 0
                                ? '<p style="font-size:12px;color:var(--vscode-editorWarning-foreground);margin-top:8px">' + d.placeholdersRemaining + ' placeholder(s) remaining — fill them in your editor.</p>'
                                : '') +
                            '<button class="btn-primary" onclick="vscode.postMessage({command:\\'cancel\\'})">Close</button>';
                    } else {
                        card.innerHTML =
                            '<h3 style="color:var(--vscode-errorForeground)">✗ Setup Failed</h3>' +
                            '<p style="font-size:13px;color:var(--vscode-descriptionForeground)">' + (d.message || 'Unknown error') + '</p>' +
                            '<button class="btn-primary" onclick="document.getElementById(\\'resultOverlay\\').classList.remove(\\'visible\\'); document.getElementById(\\'submitBtn\\').disabled = false;">Try Again</button>';
                    }

                    document.getElementById('resultOverlay').classList.add('visible');
                    break;
            }
        });
    </script>
</body>
</html>`;
  }
}
