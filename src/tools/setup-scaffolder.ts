import * as fs from 'fs';
import * as path from 'path';
import { SetupFormData, WorkspaceState } from '../schemas/setup-form-data';

export class SetupScaffolder {
  /**
   * Initializes the workspace by creating .specs/ and copying GEMINI_CONSTITUTION.md
   * @param workspaceRoot The root directory of the target workspace
   * @param extensionPath The absolute path of the extension (optional). 
   *                      If not provided, it attempts to resolve relative to __dirname.
   */
  public static initWorkspace(workspaceRoot: string, extensionPath?: string): void {
    const specsDir = path.join(workspaceRoot, '.specs');
    const destConstitution = path.join(workspaceRoot, 'GEMINI_CONSTITUTION.md');
    
    // Create .specs/ directory if it doesn't exist
    if (!fs.existsSync(specsDir)) {
      fs.mkdirSync(specsDir, { recursive: true });
      console.log(`Created directory: ${specsDir}`);
    } else {
      console.log(`Directory already exists: ${specsDir}`);
    }

    // Copy GEMINI_CONSTITUTION.md if it doesn't exist
    if (!fs.existsSync(destConstitution)) {
      // Resolve source constitution path
      let srcConstitution: string;
      if (extensionPath) {
        srcConstitution = path.join(extensionPath, 'src', 'assets', 'GEMINI_CONSTITUTION.md');
      } else {
        // Fallback for execution within compiled dist/ folder or src/ folder
        const isDist = __dirname.includes('dist');
        const baseDir = isDist ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
        srcConstitution = path.join(baseDir, 'src', 'assets', 'GEMINI_CONSTITUTION.md');
      }
      
      if (fs.existsSync(srcConstitution)) {
        fs.copyFileSync(srcConstitution, destConstitution);
        console.log(`Copied GEMINI_CONSTITUTION.md to ${destConstitution}`);
      } else {
        console.warn(`Source GEMINI_CONSTITUTION.md not found at ${srcConstitution}`);
      }
    } else {
      console.log(`File already exists: ${destConstitution}`);
    }
  }

  /**
   * Detects the current workspace setup state for idempotent behavior.
   * - 'fresh': No .specs/ and no GEMINI_CONSTITUTION.md
   * - 'partial': Has one of .specs/ or GEMINI_CONSTITUTION.md but not both
   * - 'complete': Has both .specs/ and GEMINI_CONSTITUTION.md
   */
  public static detectWorkspaceState(workspaceRoot: string): WorkspaceState {
    const specsDir = path.join(workspaceRoot, '.specs');
    const constitutionFile = path.join(workspaceRoot, 'GEMINI_CONSTITUTION.md');
    const projectConfig = path.join(workspaceRoot, 'project-config.json');

    const hasSpecs = fs.existsSync(specsDir);
    const hasConstitution = fs.existsSync(constitutionFile);
    const hasProjectConfig = fs.existsSync(projectConfig);

    if (hasSpecs && hasConstitution && hasProjectConfig) {
      return 'complete';
    }
    if (hasSpecs || hasConstitution || hasProjectConfig) {
      return 'partial';
    }
    return 'fresh';
  }

  /**
   * Creates .specs/ directory structure and writes AI-generated constitution content
   * instead of copying the default template. Idempotent — skips existing files/dirs.
   * @returns List of files/dirs created and skipped
   */
  public static initWorkspaceWithConstitution(
    workspaceRoot: string,
    constitutionContent: string
  ): { created: string[]; skipped: string[] } {
    const created: string[] = [];
    const skipped: string[] = [];

    // Create .specs/ directory
    const specsDir = path.join(workspaceRoot, '.specs');
    if (!fs.existsSync(specsDir)) {
      fs.mkdirSync(specsDir, { recursive: true });
      created.push('.specs/');
    } else {
      skipped.push('.specs/ (already exists)');
    }

    // Create .specs/ subdirectories
    const subDirs = ['_explorations', '_reviews', '_adr'];
    for (const sub of subDirs) {
      const subPath = path.join(specsDir, sub);
      if (!fs.existsSync(subPath)) {
        fs.mkdirSync(subPath, { recursive: true });
        created.push(`.specs/${sub}/`);
      } else {
        skipped.push(`.specs/${sub}/ (already exists)`);
      }
    }

    // Write GEMINI_CONSTITUTION.md
    const constitutionPath = path.join(workspaceRoot, 'GEMINI_CONSTITUTION.md');
    if (!fs.existsSync(constitutionPath)) {
      fs.writeFileSync(constitutionPath, constitutionContent, 'utf8');
      created.push('GEMINI_CONSTITUTION.md');
    } else {
      skipped.push('GEMINI_CONSTITUTION.md (already exists)');
    }

    // Write .specs/index.md
    const indexPath = path.join(specsDir, 'index.md');
    if (!fs.existsSync(indexPath)) {
      const indexContent = `# Spec index

Active specs (auto-updated by /sd:spec status transitions):

| ID | Type | Status | Created | Title |
|---|---|---|---|---|
`;
      fs.writeFileSync(indexPath, indexContent, 'utf8');
      created.push('.specs/index.md');
    } else {
      skipped.push('.specs/index.md (already exists)');
    }

    return { created, skipped };
  }

  /**
   * Generates and writes project-config.json from the template with form data substitutions.
   * Idempotent — does not overwrite existing file.
   * @returns true if file was written, false if skipped
   */
  public static writeProjectConfig(
    workspaceRoot: string,
    formData: SetupFormData,
    extensionPath?: string
  ): boolean {
    const configPath = path.join(workspaceRoot, 'project-config.json');
    if (fs.existsSync(configPath)) {
      console.log(`project-config.json already exists — skipping`);
      return false;
    }

    // Load template
    let templatePath: string;
    if (extensionPath) {
      templatePath = path.join(extensionPath, 'src', 'assets', 'templates', 'project-config.template.json');
    } else {
      const isDist = __dirname.includes('dist');
      const baseDir = isDist ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
      templatePath = path.join(baseDir, 'src', 'assets', 'templates', 'project-config.template.json');
    }

    let templateContent: string;
    if (fs.existsSync(templatePath)) {
      templateContent = fs.readFileSync(templatePath, 'utf8');
    } else {
      console.warn(`Template not found at ${templatePath}, generating minimal config`);
      templateContent = JSON.stringify({
        version: '1.0.0',
        project: { name: '<<project-name>>' },
        commands: {},
        paths: {},
      }, null, 2);
    }

    // Substitute placeholders with form data
    const config = JSON.parse(templateContent);

    // Project info
    config.project.name = formData.projectName;

    // Commands: derive defaults from language/framework where possible
    const commandDefaults = SetupScaffolder.deriveCommandDefaults(formData.language, formData.framework);
    if (commandDefaults.build) { config.commands.build = commandDefaults.build; }
    if (commandDefaults.test) { config.commands.test = commandDefaults.test; }
    if (commandDefaults.lint) { config.commands.lint = commandDefaults.lint; }
    if (commandDefaults.run) { config.commands.run = commandDefaults.run; }

    fs.writeFileSync(configPath, JSON.stringify(config, null, 2), 'utf8');
    return true;
  }

  /**
   * Derives sensible command defaults based on the selected tech stack.
   */
  private static deriveCommandDefaults(
    language: string,
    framework: string
  ): Record<string, string> {
    const lang = language.toLowerCase();
    const fw = framework.toLowerCase();

    if (lang.includes('typescript') || lang.includes('javascript') || fw.includes('node') || fw.includes('next') || fw.includes('react') || fw.includes('vue') || fw.includes('angular')) {
      return {
        build: 'npm run build',
        test: 'npm test',
        lint: 'npm run lint',
        run: 'npm run dev',
      };
    }
    if (lang.includes('python') || fw.includes('django') || fw.includes('flask') || fw.includes('fastapi')) {
      return {
        test: 'pytest',
        lint: 'ruff check .',
        run: 'python -m <<module>>',
      };
    }
    if (lang.includes('c#') || lang.includes('.net') || fw.includes('asp.net') || fw.includes('blazor')) {
      return {
        build: 'dotnet build',
        test: 'dotnet test',
        lint: 'dotnet format --verify-no-changes',
        run: 'dotnet run',
      };
    }
    if (lang.includes('java') || fw.includes('spring')) {
      return {
        build: 'mvn package',
        test: 'mvn test',
        run: 'mvn spring-boot:run',
      };
    }
    if (lang.includes('go') || fw.includes('gin') || fw.includes('fiber')) {
      return {
        build: 'go build ./...',
        test: 'go test ./...',
        lint: 'golangci-lint run',
        run: 'go run .',
      };
    }
    if (lang.includes('rust') || fw.includes('actix') || fw.includes('axum')) {
      return {
        build: 'cargo build',
        test: 'cargo test',
        lint: 'cargo clippy',
        run: 'cargo run',
      };
    }

    return {};
  }
}
