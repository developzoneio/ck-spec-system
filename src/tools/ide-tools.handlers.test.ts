import { IdeToolHandlers } from './ide-tools.handlers';
import * as vscode from 'vscode';
import { Uri, FileType } from 'vscode';

// We mock vscode in __mocks__/vscode.ts
const mockedWorkspace = vscode.workspace as jest.Mocked<typeof vscode.workspace>;

describe('IdeToolHandlers', () => {
  let handlers: IdeToolHandlers;
  const rootUri = Uri.file('/mock/workspace/root');

  beforeEach(() => {
    handlers = new IdeToolHandlers(rootUri);
    jest.clearAllMocks();
  });

  describe('ide_read_file', () => {
    it('should read a full file and add line numbers', async () => {
      const mockContent = 'line1\nline2\nline3';
      mockedWorkspace.fs.stat = jest.fn().mockResolvedValue({ type: FileType.File, size: 100 });
      mockedWorkspace.fs.readFile = jest.fn().mockResolvedValue(new TextEncoder().encode(mockContent));

      const result = await handlers.dispatch('ide_read_file', { path: 'test.txt' });

      expect(mockedWorkspace.fs.stat).toHaveBeenCalledWith(Uri.joinPath(rootUri, 'test.txt'));
      expect(mockedWorkspace.fs.readFile).toHaveBeenCalledWith(Uri.joinPath(rootUri, 'test.txt'));
      expect(result).toBe('1: line1\n2: line2\n3: line3');
    });

    it('should return error for files exceeding max size', async () => {
      mockedWorkspace.fs.stat = jest.fn().mockResolvedValue({ type: FileType.File, size: 200 * 1024 });

      const result = await handlers.dispatch('ide_read_file', { path: 'large.txt' });

      expect(result).toContain('Error: File \'large.txt\' is too large to read');
      expect(mockedWorkspace.fs.readFile).not.toHaveBeenCalled();
    });

    it('should detect and reject binary files based on null bytes', async () => {
      const binaryContent = new Uint8Array([0x48, 0x65, 0x00, 0x6c, 0x6f]); // "He\0lo"
      mockedWorkspace.fs.stat = jest.fn().mockResolvedValue({ type: FileType.File, size: 5 });
      mockedWorkspace.fs.readFile = jest.fn().mockResolvedValue(binaryContent);

      const result = await handlers.dispatch('ide_read_file', { path: 'unknown.dat' });

      expect(result).toContain('Error: File \'unknown.dat\' appears to be a binary file');
    });

    it('should reject path traversal', async () => {
      const result = await handlers.dispatch('ide_read_file', { path: '../outside.txt' });
      expect(result).toContain('Error: Path traversal is not allowed');
    });
    
    it('should read specific line range', async () => {
      const mockContent = 'line1\nline2\nline3\nline4\nline5';
      mockedWorkspace.fs.stat = jest.fn().mockResolvedValue({ type: FileType.File, size: 100 });
      mockedWorkspace.fs.readFile = jest.fn().mockResolvedValue(new TextEncoder().encode(mockContent));

      const result = await handlers.dispatch('ide_read_file', { path: 'test.txt', startLine: 2, endLine: 4 });

      expect(result).toBe('2: line2\n3: line3\n4: line4');
    });
  });

  describe('ide_list_directory', () => {
    it('should list directory contents with correct prefixes and sorting', async () => {
      const mockEntries: [string, vscode.FileType][] = [
        ['fileA.ts', FileType.File],
        ['dirB', FileType.Directory],
        ['fileZ.ts', FileType.File],
        ['dirA', FileType.Directory],
      ];
      mockedWorkspace.fs.readDirectory = jest.fn().mockResolvedValue(mockEntries);

      const result = await handlers.dispatch('ide_list_directory', { path: 'src' });

      expect(mockedWorkspace.fs.readDirectory).toHaveBeenCalledWith(Uri.joinPath(rootUri, 'src'));
      expect(result).toBe('[DIR] dirA\n[DIR] dirB\n[FILE] fileA.ts\n[FILE] fileZ.ts');
    });

    it('should return error for invalid directory', async () => {
      mockedWorkspace.fs.readDirectory = jest.fn().mockRejectedValue(new Error('ENOENT: no such file'));

      const result = await handlers.dispatch('ide_list_directory', { path: 'nonexistent' });

      expect(result).toContain('Error listing directory');
    });
  });

  describe('ide_search_text', () => {
    it('should find matches and format correctly', async () => {
      const mockFiles = [Uri.joinPath(rootUri, 'file1.ts'), Uri.joinPath(rootUri, 'file2.ts')];
      const mockContent1 = 'const a = 1;\nconsole.log("hello");\n';
      const mockContent2 = 'function test() {\n  return "hello world";\n}';
      
      mockedWorkspace.findFiles = jest.fn().mockResolvedValue(mockFiles);
      mockedWorkspace.fs.stat = jest.fn().mockResolvedValue({ type: FileType.File, size: 100 });
      
      mockedWorkspace.fs.readFile = jest.fn()
        .mockResolvedValueOnce(new TextEncoder().encode(mockContent1))
        .mockResolvedValueOnce(new TextEncoder().encode(mockContent2));

      const result = await handlers.dispatch('ide_search_text', { query: 'hello', pattern: '**/*.ts' });

      expect(mockedWorkspace.findFiles).toHaveBeenCalledWith('**/*.ts');
      expect(result).toBe('file1.ts:2: console.log("hello");\nfile2.ts:2:   return "hello world";');
    });

    it('should truncate results if exceeding limit', async () => {
      const mockFiles = [Uri.joinPath(rootUri, 'file1.ts')];
      
      // Generate 55 matches
      const lines = new Array(55).fill('match this string');
      const mockContent = lines.join('\n');
      
      mockedWorkspace.findFiles = jest.fn().mockResolvedValue(mockFiles);
      mockedWorkspace.fs.stat = jest.fn().mockResolvedValue({ type: FileType.File, size: 1000 });
      mockedWorkspace.fs.readFile = jest.fn().mockResolvedValue(new TextEncoder().encode(mockContent));

      const result = await handlers.dispatch('ide_search_text', { query: 'match', pattern: '*.ts' });

      const resultLines = result.split('\n');
      // 50 match lines + 1 empty line + 1 warning line
      expect(resultLines.length).toBe(52); 
      expect(result).toContain('[WARNING: Results truncated at 50 matches.');
    });
  });

  describe('ide_apply_diff', () => {
    it('should open diff viewer when search block is found', async () => {
      const mockContent = 'line1\nline2\nline3\nline4\nline5';
      mockedWorkspace.fs.stat = jest.fn().mockResolvedValue({ type: FileType.File, size: 100 });
      mockedWorkspace.fs.readFile = jest.fn().mockResolvedValue(new TextEncoder().encode(mockContent));

      const result = await handlers.dispatch('ide_apply_diff', { 
        path: 'test.txt',
        search_block: 'line2\nline3',
        replace_block: 'line2_new\nline3_new'
      });

      expect(vscode.commands.executeCommand).toHaveBeenCalledWith(
        'vscode.diff',
        Uri.joinPath(rootUri, 'test.txt'),
        expect.any(Object),
        'Diff: test.txt'
      );
      expect(result).toContain('Diff viewer opened');
    });

    it('should return error if search block not found', async () => {
      const mockContent = 'line1\nline2\nline3';
      mockedWorkspace.fs.stat = jest.fn().mockResolvedValue({ type: FileType.File, size: 100 });
      mockedWorkspace.fs.readFile = jest.fn().mockResolvedValue(new TextEncoder().encode(mockContent));

      const result = await handlers.dispatch('ide_apply_diff', { 
        path: 'test.txt',
        search_block: 'lineX',
        replace_block: 'lineY'
      });

      expect(result).toContain('Error: \'search_block\' not found');
    });

    it('should return error if search block is ambiguous', async () => {
      const mockContent = 'line1\nlineX\nline2\nlineX\nline3';
      mockedWorkspace.fs.stat = jest.fn().mockResolvedValue({ type: FileType.File, size: 100 });
      mockedWorkspace.fs.readFile = jest.fn().mockResolvedValue(new TextEncoder().encode(mockContent));

      const result = await handlers.dispatch('ide_apply_diff', { 
        path: 'test.txt',
        search_block: 'lineX',
        replace_block: 'lineY'
      });

      expect(result).toContain('Error: \'search_block\' is ambiguous');
    });
  });

  describe('ide_write_new_file', () => {
    it('should open diff viewer for new file', async () => {
      mockedWorkspace.fs.stat = jest.fn().mockRejectedValue(new Error('File not found'));

      const result = await handlers.dispatch('ide_write_new_file', { 
        path: 'new.txt',
        content: 'hello world'
      });

      expect(vscode.commands.executeCommand).toHaveBeenCalledWith(
        'vscode.diff',
        expect.any(Object),
        expect.any(Object),
        'New File: new.txt'
      );
      expect(result).toContain('Diff viewer opened');
    });

    it('should return error if file already exists', async () => {
      mockedWorkspace.fs.stat = jest.fn().mockResolvedValue({ type: FileType.File, size: 100 });

      const result = await handlers.dispatch('ide_write_new_file', { 
        path: 'exists.txt',
        content: 'hello world'
      });

      expect(result).toContain('already exists');
    });
  });

  describe('ide_get_diagnostics', () => {
    const mockDiagnostics = [
      {
        severity: vscode.DiagnosticSeverity.Error,
        message: "Type 'string' is not assignable to type 'number'.",
        range: { start: { line: 41, character: 4 } },
        code: "ts2322"
      },
      {
        severity: vscode.DiagnosticSeverity.Warning,
        message: "Variable is declared but never used.",
        range: { start: { line: 10, character: 2 } }
      }
    ];

    beforeEach(() => {
      vscode.languages.getDiagnostics = jest.fn().mockReturnValue(mockDiagnostics);
    });

    it('should return formatted error diagnostics by default', async () => {
      const result = await handlers.dispatch('ide_get_diagnostics', { path: 'test.ts' });
      expect(vscode.languages.getDiagnostics).toHaveBeenCalledWith(Uri.joinPath(rootUri, 'test.ts'));
      expect(result).toBe('Line 42, Col 5 [Error]: Type \'string\' is not assignable to type \'number\'. (ts2322)');
    });

    it('should return "No diagnostics found" for clean files', async () => {
      vscode.languages.getDiagnostics = jest.fn().mockReturnValue([]);
      const result = await handlers.dispatch('ide_get_diagnostics', { path: 'test.ts' });
      expect(result).toBe('No diagnostics found.');
    });

    it('should filter by severity (error only)', async () => {
      const result = await handlers.dispatch('ide_get_diagnostics', { path: 'test.ts', severity: 'error' });
      expect(result).toContain('[Error]');
      expect(result).not.toContain('[Warning]');
    });

    it('should filter by severity (warning only)', async () => {
      const result = await handlers.dispatch('ide_get_diagnostics', { path: 'test.ts', severity: 'warning' });
      expect(result).not.toContain('[Error]');
      expect(result).toContain('[Warning]');
    });

    it('should return all when severity is "all"', async () => {
      const result = await handlers.dispatch('ide_get_diagnostics', { path: 'test.ts', severity: 'all' });
      expect(result).toContain('[Error]');
      expect(result).toContain('[Warning]');
    });

    it('should reject path traversal', async () => {
      const result = await handlers.dispatch('ide_get_diagnostics', { path: '../outside.ts' });
      expect(result).toContain('Error: Path traversal is not allowed');
    });

    it('should truncate at 50 results', async () => {
      const manyDiagnostics = Array(60).fill({
        severity: vscode.DiagnosticSeverity.Error,
        message: "Error",
        range: { start: { line: 0, character: 0 } }
      });
      vscode.languages.getDiagnostics = jest.fn().mockReturnValue(manyDiagnostics);
      
      const result = await handlers.dispatch('ide_get_diagnostics', { path: 'test.ts' });
      
      const lines = result.split('\n');
      expect(lines.length).toBe(52); // 50 matches + 1 empty line + 1 warning
      expect(result).toContain('[WARNING: Results truncated at 50 diagnostics.');
    });
  });

  describe('dispatch', () => {
    it('should return error for unknown tool', async () => {
      const result = await handlers.dispatch('unknown_tool', {});
      expect(result).toBe("Error: Unknown tool 'unknown_tool'");
    });
  });
});
