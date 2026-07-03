import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import ignore from 'ignore';
import { GoogleGenAI } from '@google/genai';

export class CacheManager {
  private cacheName: string | null = null;
  private expireTime: number | null = null;

  constructor(private apiKey: string) {}

  private async getWorkspacePath(): Promise<string | null> {
    const folders = vscode.workspace.workspaceFolders;
    if (!folders || folders.length === 0) {
      return null;
    }
    return folders[0].uri.fsPath;
  }

  private async getIgnoreFilter(workspacePath: string) {
    const ig = ignore();
    // Default ignores for VS Code extension and common build artifacts
    ig.add(['.git', 'node_modules', 'dist', 'out']);
    
    const gitignorePath = path.join(workspacePath, '.gitignore');
    try {
      if (fs.existsSync(gitignorePath)) {
        const gitignoreContent = await fs.promises.readFile(gitignorePath, 'utf8');
        ig.add(gitignoreContent);
      }
    } catch (e) {
      // Ignore errors reading gitignore
    }
    return ig;
  }

  private async scanFiles(dir: string, baseDir: string, ig: ReturnType<typeof ignore>): Promise<string[]> {
    const files: string[] = [];
    let entries;
    try {
      entries = await fs.promises.readdir(dir, { withFileTypes: true });
    } catch (e) {
      return files;
    }
    
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      const relativePath = path.relative(baseDir, fullPath);
      
      // Use ignore filter (always use forward slashes for ignore library)
      const relativePathUnix = relativePath.replace(/\\/g, '/');
      if (ig.ignores(relativePathUnix)) {
        continue;
      }
      
      if (entry.isDirectory()) {
        const subFiles = await this.scanFiles(fullPath, baseDir, ig);
        files.push(...subFiles);
      } else {
        files.push(fullPath);
      }
    }
    
    return files;
  }

  public async getWorkspaceContent(): Promise<string> {
    const workspacePath = await this.getWorkspacePath();
    if (!workspacePath) {
      throw new Error("No workspace opened");
    }
    
    const ig = await this.getIgnoreFilter(workspacePath);
    const files = await this.scanFiles(workspacePath, workspacePath, ig);
    
    let combinedContent = "";
    for (const file of files) {
      try {
        const content = await fs.promises.readFile(file, 'utf8');
        const relativePath = path.relative(workspacePath, file);
        combinedContent += `\n\n--- File: ${relativePath} ---\n\n${content}`;
      } catch (e) {
        // Skip unreadable files or binary files
      }
    }
    
    return combinedContent;
  }

  public async ensureCache(): Promise<string | null> {
    const now = Date.now();
    if (this.cacheName && this.expireTime && now < this.expireTime) {
        // Cache is still valid
        return this.cacheName;
    }
    
    const content = await this.getWorkspaceContent();
    const ai = new GoogleGenAI({ apiKey: this.apiKey });
    
    const cacheResult = await ai.caches.create({
      model: 'gemini-1.5-pro-001',
      contents: [{
         role: 'user',
         parts: [{ text: content }]
      }],
      config: {
        ttl: '3600s' // 1 hour
      }
    } as any);
    
    this.cacheName = cacheResult.name || null;
    
    if (cacheResult.expireTime) {
      this.expireTime = new Date(cacheResult.expireTime).getTime() - 60000;
    } else {
      this.expireTime = now + 3600 * 1000 - 60000;
    }
    
    return this.cacheName;
  }

  public getCacheName(): string | null {
    return this.cacheName;
  }
}
