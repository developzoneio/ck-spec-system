import * as vscode from 'vscode';
import { SetupFormData, SetupResult } from '../schemas/setup-form-data';
import { SpecArchitectAgent } from '../agents/spec-architect';
import { IdeToolHandlers } from '../tools/ide-tools.handlers';
import { SetupScaffolder } from '../tools/setup-scaffolder';

/**
 * Orchestrates the full setup pipeline:
 *   FormData → AI Constitution Generation → Scaffold .specs/ → Write project-config.json → Report
 */
export class SetupOrchestrator {
  private extensionPath: string;

  constructor(private context: vscode.ExtensionContext) {
    this.extensionPath = context.extensionPath;
  }

  /**
   * Runs the complete setup pipeline.
   * @param formData Collected from the Webview form
   * @param workspaceRoot Absolute path to the workspace root
   */
  public async run(formData: SetupFormData, workspaceRoot: string): Promise<SetupResult> {
    const filesCreated: string[] = [];
    const filesSkipped: string[] = [];
    let constitutionGenerated = false;

    try {
      // Step 1: Generate personalized GEMINI_CONSTITUTION.md via AI
      const constitutionContent = await this.generateConstitution(formData, workspaceRoot);
      constitutionGenerated = true;

      // Step 2: Scaffold .specs/ directory and write constitution
      const scaffoldResult = SetupScaffolder.initWorkspaceWithConstitution(
        workspaceRoot,
        constitutionContent
      );
      filesCreated.push(...scaffoldResult.created);
      filesSkipped.push(...scaffoldResult.skipped);

      // Step 3: Generate project-config.json
      const configWritten = SetupScaffolder.writeProjectConfig(
        workspaceRoot,
        formData,
        this.extensionPath
      );
      if (configWritten) {
        filesCreated.push('project-config.json');
      } else {
        filesSkipped.push('project-config.json (already exists)');
      }

      // Step 4: Count remaining placeholders
      const placeholdersRemaining = this.countPlaceholders(workspaceRoot);

      return {
        success: true,
        filesCreated,
        filesSkipped,
        placeholdersRemaining,
        constitutionGenerated,
        message: `Setup complete. ${filesCreated.length} file(s) created, ${filesSkipped.length} skipped.`,
      };
    } catch (error: any) {
      return {
        success: false,
        filesCreated,
        filesSkipped,
        placeholdersRemaining: 0,
        constitutionGenerated,
        message: error.message || 'An unknown error occurred during setup.',
      };
    }
  }

  /**
   * Calls the SpecArchitectAgent to generate a personalized constitution.
   * Falls back to template-based substitution if the API key is not configured.
   */
  private async generateConstitution(formData: SetupFormData, workspaceRoot: string): Promise<string> {
    const apiKey = process.env.GEMINI_API_KEY
      || vscode.workspace.getConfiguration('specwright').get<string>('apiKey');

    if (!apiKey) {
      // Fallback: simple template substitution without AI
      return this.generateConstitutionFromTemplate(formData);
    }

    try {
      const toolHandlers = new IdeToolHandlers(workspaceRoot);
      const agent = new SpecArchitectAgent({ apiKey }, toolHandlers);
      return await agent.generateConstitution(formData);
    } catch (error: any) {
      console.warn('AI constitution generation failed, falling back to template:', error.message);
      return this.generateConstitutionFromTemplate(formData);
    }
  }

  /**
   * Fallback: generate constitution from template with simple placeholder replacement.
   * Used when the Gemini API key is not available.
   */
  private generateConstitutionFromTemplate(formData: SetupFormData): string {
    const fs = require('fs');
    const path = require('path');

    const templatePath = path.join(this.extensionPath, 'src', 'assets', 'templates', 'GEMINI_CONSTITUTION.template.md');

    let template: string;
    if (fs.existsSync(templatePath)) {
      template = fs.readFileSync(templatePath, 'utf8');
    } else {
      // Minimal fallback
      template = `# ${formData.projectName}\n\n## Stack\n\n- **Language**: ${formData.language}\n- **Framework**: ${formData.framework}\n`;
    }

    // Replace known placeholders
    template = template.replace(/<<project-name>>/g, formData.projectName);
    template = template.replace(/<<language-and-version>>/g, formData.language);
    template = template.replace(/<<framework-and-version>>/g, formData.framework || '<<framework-and-version>>');
    template = template.replace(/<<db-and-version>>/g, formData.database || '<<db-and-version>>');

    // Inject team rules into Code conventions section if provided
    if (formData.teamRules) {
      const rules = formData.teamRules
        .split('\n')
        .filter((line: string) => line.trim())
        .map((line: string) => `- ${line.trim().replace(/^[-*]\s*/, '')}`)
        .join('\n');

      template = template.replace(
        /- <<convention-1.*?>>\n- <<convention-2.*?>>\n- <<convention-3.*?>>\n- <<convention-4.*?>>/,
        rules
      );
    }

    return template;
  }

  /**
   * Counts remaining <<placeholder>> tokens in generated files.
   */
  private countPlaceholders(workspaceRoot: string): number {
    const fs = require('fs');
    const path = require('path');
    let count = 0;

    const filesToCheck = [
      path.join(workspaceRoot, 'GEMINI_CONSTITUTION.md'),
      path.join(workspaceRoot, '.specs', 'constitution.md'),
    ];

    for (const filePath of filesToCheck) {
      if (fs.existsSync(filePath)) {
        const content = fs.readFileSync(filePath, 'utf8');
        const matches = content.match(/<<[^>]+>>/g);
        if (matches) {
          count += matches.length;
        }
      }
    }

    return count;
  }
}
