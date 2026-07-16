import { IDE_TOOL_DECLARATIONS, IDE_TOOLS_CONFIG } from './ide-tools.declarations';
import { Type } from '@google/genai';

describe('ide-tools.declarations', () => {
  it('should export IDE_TOOLS_CONFIG with functionDeclarations', () => {
    expect(IDE_TOOLS_CONFIG).toBeDefined();
    expect(IDE_TOOLS_CONFIG.functionDeclarations).toBe(IDE_TOOL_DECLARATIONS);
  });

  it('should contain exactly 6 tools', () => {
    expect(IDE_TOOL_DECLARATIONS.length).toBe(6);
  });

  it('should define ide_read_file correctly', () => {
    const decl = IDE_TOOL_DECLARATIONS.find(d => d.name === 'ide_read_file');
    expect(decl).toBeDefined();
    expect(decl?.parameters?.type).toBe(Type.OBJECT);
    expect(decl?.parameters?.required).toContain('path');
    const props = decl?.parameters?.properties as any;
    expect(props?.path.type).toBe(Type.STRING);
    expect(props?.startLine.type).toBe(Type.INTEGER);
    expect(props?.endLine.type).toBe(Type.INTEGER);
  });

  it('should define ide_list_directory correctly', () => {
    const decl = IDE_TOOL_DECLARATIONS.find(d => d.name === 'ide_list_directory');
    expect(decl).toBeDefined();
    expect(decl?.parameters?.type).toBe(Type.OBJECT);
    expect(decl?.parameters?.required).toContain('path');
    const props = decl?.parameters?.properties as any;
    expect(props?.path.type).toBe(Type.STRING);
  });

  it('should define ide_search_text correctly', () => {
    const decl = IDE_TOOL_DECLARATIONS.find(d => d.name === 'ide_search_text');
    expect(decl).toBeDefined();
    expect(decl?.parameters?.type).toBe(Type.OBJECT);
    expect(decl?.parameters?.required).toContain('query');
    expect(decl?.parameters?.required).toContain('pattern');
    const props = decl?.parameters?.properties as any;
    expect(props?.query.type).toBe(Type.STRING);
    expect(props?.pattern.type).toBe(Type.STRING);
  });

  it('should define ide_apply_diff correctly', () => {
    const decl = IDE_TOOL_DECLARATIONS.find(d => d.name === 'ide_apply_diff');
    expect(decl).toBeDefined();
    expect(decl?.parameters?.type).toBe(Type.OBJECT);
    expect(decl?.parameters?.required).toContain('path');
    expect(decl?.parameters?.required).toContain('search_block');
    expect(decl?.parameters?.required).toContain('replace_block');
  });

  it('should define ide_write_new_file correctly', () => {
    const decl = IDE_TOOL_DECLARATIONS.find(d => d.name === 'ide_write_new_file');
    expect(decl).toBeDefined();
    expect(decl?.parameters?.type).toBe(Type.OBJECT);
    expect(decl?.parameters?.required).toContain('path');
    expect(decl?.parameters?.required).toContain('content');
  });

  it('should define ide_get_diagnostics correctly', () => {
    const decl = IDE_TOOL_DECLARATIONS.find(d => d.name === 'ide_get_diagnostics');
    expect(decl).toBeDefined();
    expect(decl?.parameters?.type).toBe(Type.OBJECT);
    expect(decl?.parameters?.required).toContain('path');
    const props = decl?.parameters?.properties as any;
    expect(props?.path.type).toBe(Type.STRING);
    expect(props?.severity.type).toBe(Type.STRING);
  });
});
