import * as fs from 'fs';
import * as path from 'path';

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
}
