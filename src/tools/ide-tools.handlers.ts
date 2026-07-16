import * as vscode from 'vscode';

export class IdeToolHandlers {
  private static MAX_FILE_SIZE_BYTES = 100 * 1024; // 100KB
  private static MAX_SEARCH_RESULTS = 50;
  // Blocklist for common binary or minified files to save I/O
  private static BINARY_EXTENSIONS = new Set(['.png', '.jpg', '.jpeg', '.gif', '.exe', '.dll', '.zip', '.tar', '.gz', '.pdf', '.mp4', '.mp3']);

  constructor(private workspaceRoot: vscode.Uri) {}

  public async dispatch(toolName: string, args: Record<string, unknown>): Promise<string> {
    switch (toolName) {
      case 'ide_read_file':
        return this.handleReadFile(
          args.path as string,
          args.startLine as number | undefined,
          args.endLine as number | undefined
        );
      case 'ide_list_directory':
        return this.handleListDirectory(args.path as string);
      case 'ide_search_text':
        return this.handleSearchText(args.query as string, args.pattern as string);
      case 'ide_apply_diff':
        return this.handleApplyDiff(args.path as string, args.search_block as string, args.replace_block as string, args.description as string | undefined);
      case 'ide_write_new_file':
        return this.handleWriteNewFile(args.path as string, args.content as string, args.description as string | undefined);
      case 'ide_get_diagnostics':
        return this.handleGetDiagnostics(args.path as string, args.severity as string | undefined);
      default:
        return `Error: Unknown tool '${toolName}'`;
    }
  }

  private resolvePath(relativePath: string): vscode.Uri | null {
    if (relativePath.includes('..')) {
      return null;
    }
    return vscode.Uri.joinPath(this.workspaceRoot, relativePath);
  }

  private async isBinary(uri: vscode.Uri, fileBuffer?: Uint8Array): Promise<boolean> {
    const ext = uri.path.substring(uri.path.lastIndexOf('.')).toLowerCase();
    if (IdeToolHandlers.BINARY_EXTENSIONS.has(ext)) {
      return true;
    }

    // Null-byte check on the first chunk
    let bufferToCheck = fileBuffer;
    if (!bufferToCheck) {
        try {
            // If buffer isn't provided, we'd ideally read a chunk. 
            // VS Code workspace.fs.readFile doesn't support chunking directly, 
            // but reading the whole file is fast enough for the <100KB limit we enforce.
            bufferToCheck = await vscode.workspace.fs.readFile(uri);
        } catch (e) {
            return false; // Can't read, let subsequent read handle the error
        }
    }

    const checkLength = Math.min(bufferToCheck.length, 8192); // Check up to 8KB
    for (let i = 0; i < checkLength; i++) {
      if (bufferToCheck[i] === 0) {
        return true;
      }
    }
    return false;
  }

  private async handleReadFile(path: string, startLine?: number, endLine?: number): Promise<string> {
    const uri = this.resolvePath(path);
    if (!uri) {
      return 'Error: Path traversal is not allowed.';
    }

    try {
      const stat = await vscode.workspace.fs.stat(uri);
      
      if (stat.type !== vscode.FileType.File) {
        return `Error: '${path}' is not a file.`;
      }

      if (stat.size > IdeToolHandlers.MAX_FILE_SIZE_BYTES) {
        return `Error: File '${path}' is too large to read (Size: ${stat.size} bytes. Limit: ${IdeToolHandlers.MAX_FILE_SIZE_BYTES} bytes). Please use search or narrow your investigation.`;
      }

      const rawData = await vscode.workspace.fs.readFile(uri);
      
      if (await this.isBinary(uri, rawData)) {
          return `Error: File '${path}' appears to be a binary file. Reading binary files is not supported.`;
      }

      const content = new TextDecoder('utf-8').decode(rawData);
      const lines = content.split(/\r?\n/);

      let start = 0;
      let end = lines.length;

      if (startLine !== undefined) {
        start = Math.max(0, startLine - 1);
      }
      if (endLine !== undefined) {
        end = Math.min(lines.length, endLine);
      }

      if (start > end || start >= lines.length) {
         return `Error: Invalid line range. File has ${lines.length} lines.`;
      }

      const selectedLines = lines.slice(start, end).map((line, index) => `${start + index + 1}: ${line}`);
      return selectedLines.join('\n');

    } catch (e: any) {
       return `Error reading file: ${e.message || 'File not found'}`;
    }
  }

  private async handleListDirectory(path: string): Promise<string> {
    const uri = path === '.' || path === './' ? this.workspaceRoot : this.resolvePath(path);
    if (!uri) {
      return 'Error: Path traversal is not allowed.';
    }

    try {
      const entries = await vscode.workspace.fs.readDirectory(uri);
      if (entries.length === 0) {
        return 'Directory is empty.';
      }

      // Sort: Directories first, then files, alphabetically
      entries.sort((a, b) => {
        if (a[1] === b[1]) {
          return a[0].localeCompare(b[0]);
        }
        return a[1] === vscode.FileType.Directory ? -1 : 1;
      });

      const output = entries.map(([name, type]) => {
        const prefix = type === vscode.FileType.Directory ? '[DIR]' : '[FILE]';
        return `${prefix} ${name}`;
      });

      return output.join('\n');
    } catch (e: any) {
       return `Error listing directory: ${e.message || 'Directory not found'}`;
    }
  }

  private async handleSearchText(query: string, pattern: string): Promise<string> {
    try {
      // Find files matching the glob pattern. VS Code automatically respects .gitignore
      const files = await vscode.workspace.findFiles(pattern);
      if (files.length === 0) {
        return `No files matched the pattern '${pattern}'.`;
      }

      const results: string[] = [];
      let isRegex = false;
      let regex: RegExp | null = null;
      
      // Attempt to treat query as regex if it looks like one or is complex, 
      // but fallback to string matching for simplicity.
      try {
          // Very basic check, if it's alphanumeric we prefer includes for speed
          if (!/^[a-zA-Z0-9\s]+$/.test(query)) {
            regex = new RegExp(query, 'g');
            isRegex = true;
          }
      } catch (e) {
          // Invalid regex, fallback to string search
      }

      for (const uri of files) {
        // Skip binary checks on search to keep it fast, or rely on .gitignore to exclude binaries
        // But let's avoid obviously large files
        try {
            const stat = await vscode.workspace.fs.stat(uri);
            if (stat.size > IdeToolHandlers.MAX_FILE_SIZE_BYTES * 2) { // Allow slightly larger for search, but not massive
                continue;
            }
            
            // Basic extension check to skip binaries in search
            const ext = uri.path.substring(uri.path.lastIndexOf('.')).toLowerCase();
            if (IdeToolHandlers.BINARY_EXTENSIONS.has(ext)) {
               continue; 
            }

            const rawData = await vscode.workspace.fs.readFile(uri);
            const content = new TextDecoder('utf-8').decode(rawData);
            const lines = content.split(/\r?\n/);
            
            // Check for null bytes to skip binary files during search
            let isBinary = false;
            for(let i=0; i<Math.min(rawData.length, 1024); i++) {
                if(rawData[i] === 0) {
                    isBinary = true;
                    break;
                }
            }
            if (isBinary) continue;

            for (let i = 0; i < lines.length; i++) {
              const line = lines[i];
              let matched = false;

              if (isRegex && regex) {
                matched = regex.test(line);
                regex.lastIndex = 0; // Reset
              } else {
                matched = line.includes(query);
              }

              if (matched) {
                const relativePath = vscode.workspace.asRelativePath(uri, false);
                results.push(`${relativePath}:${i + 1}: ${line}`);
                if (results.length >= IdeToolHandlers.MAX_SEARCH_RESULTS) {
                  return results.join('\n') + `\n\n[WARNING: Results truncated at ${IdeToolHandlers.MAX_SEARCH_RESULTS} matches. Please refine your 'query' or make the 'pattern' more specific to find exact matches]`;
                }
              }
            }
        } catch (e) {
            // Ignore individual file read errors during search
        }
      }

      if (results.length === 0) {
        return `No matches found for '${query}' in files matching '${pattern}'.`;
      }

      return results.join('\n');

    } catch (e: any) {
      return `Error searching text: ${e.message}`;
    }
  }

  private async handleApplyDiff(path: string, searchBlock: string, replaceBlock: string, description?: string): Promise<string> {
    const uri = this.resolvePath(path);
    if (!uri) return 'Error: Path traversal is not allowed.';

    try {
      const stat = await vscode.workspace.fs.stat(uri);
      if (stat.type !== vscode.FileType.File) return `Error: '${path}' is not a file.`;

      const rawData = await vscode.workspace.fs.readFile(uri);
      if (await this.isBinary(uri, rawData)) {
        return `Error: File '${path}' appears to be a binary file. Diffing binary files is not supported.`;
      }

      const content = new TextDecoder('utf-8').decode(rawData);
      
      const matchIndex = content.indexOf(searchBlock);
      if (matchIndex === -1) {
        return `Error: 'search_block' not found in file '${path}'. Please make sure you provided the exact text including whitespace.`;
      }
      
      if (content.indexOf(searchBlock, matchIndex + searchBlock.length) !== -1) {
        return `Error: 'search_block' is ambiguous (found multiple times in file '${path}'). Please provide a larger search block to ensure a unique match.`;
      }

      const newContent = content.substring(0, matchIndex) + replaceBlock + content.substring(matchIndex + searchBlock.length);
      
      const virtualUri = vscode.Uri.parse(`specwright-diff:${uri.path}`);
      
      await vscode.commands.executeCommand('specwright.updateVirtualDoc', virtualUri, newContent);
      await vscode.commands.executeCommand('vscode.diff', uri, virtualUri, `Diff: ${path}`);
      
      return `Diff viewer opened for '${path}'. ${description ? '(' + description + ')' : ''} The file on disk has NOT been modified yet. The user must review and save.`;
    } catch (e: any) {
      return `Error applying diff: ${e.message || 'File not found'}`;
    }
  }

  private async handleWriteNewFile(path: string, content: string, description?: string): Promise<string> {
    const uri = this.resolvePath(path);
    if (!uri) return 'Error: Path traversal is not allowed.';

    try {
      try {
        await vscode.workspace.fs.stat(uri);
        return `Error: File '${path}' already exists. Please use 'ide_apply_diff' to modify it.`;
      } catch (e) {
        // File doesn't exist, which is what we want
      }

      const emptyVirtualUri = vscode.Uri.parse(`specwright-diff:empty-${Date.now()}`);
      const newVirtualUri = vscode.Uri.parse(`specwright-diff:${uri.path}`);
      
      await vscode.commands.executeCommand('specwright.updateVirtualDoc', emptyVirtualUri, '');
      await vscode.commands.executeCommand('specwright.updateVirtualDoc', newVirtualUri, content);
      
      await vscode.commands.executeCommand('vscode.diff', emptyVirtualUri, newVirtualUri, `New File: ${path}`);
      
      return `Diff viewer opened for new file '${path}'. ${description ? '(' + description + ')' : ''} The file on disk has NOT been created yet. The user must review and save.`;
    } catch (e: any) {
      return `Error creating new file: ${e.message}`;
    }
  }

  private async handleGetDiagnostics(path: string, severity?: string): Promise<string> {
    const uri = this.resolvePath(path);
    if (!uri) {
      return 'Error: Path traversal is not allowed.';
    }

    try {
      const allDiagnostics = vscode.languages.getDiagnostics(uri);
      
      let filteredDiagnostics = allDiagnostics;
      if (severity === 'error') {
        filteredDiagnostics = allDiagnostics.filter(d => d.severity === vscode.DiagnosticSeverity.Error);
      } else if (severity === 'warning') {
        filteredDiagnostics = allDiagnostics.filter(d => d.severity === vscode.DiagnosticSeverity.Warning);
      } else if (severity !== 'all') {
        // Default to error
        filteredDiagnostics = allDiagnostics.filter(d => d.severity === vscode.DiagnosticSeverity.Error);
      }

      if (filteredDiagnostics.length === 0) {
        return 'No diagnostics found.';
      }

      const results: string[] = [];
      for (const diag of filteredDiagnostics) {
        let severityLabel = 'Info';
        if (diag.severity === vscode.DiagnosticSeverity.Error) {
          severityLabel = 'Error';
        } else if (diag.severity === vscode.DiagnosticSeverity.Warning) {
          severityLabel = 'Warning';
        } else if (diag.severity === vscode.DiagnosticSeverity.Hint) {
          severityLabel = 'Hint';
        }

        const line = diag.range.start.line + 1; // 0-indexed to 1-indexed
        const col = diag.range.start.character + 1;
        const codeStr = diag.code ? ` (${diag.code})` : '';
        
        results.push(`Line ${line}, Col ${col} [${severityLabel}]: ${diag.message}${codeStr}`);
        
        if (results.length >= IdeToolHandlers.MAX_SEARCH_RESULTS) {
          return results.join('\n') + `\n\n[WARNING: Results truncated at ${IdeToolHandlers.MAX_SEARCH_RESULTS} diagnostics. Please fix existing errors to see more.]`;
        }
      }

      return results.join('\n');
    } catch (e: any) {
      return `Error getting diagnostics: ${e.message || 'Unknown error'}`;
    }
  }
}
