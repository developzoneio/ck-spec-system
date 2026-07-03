import * as fs from 'fs';

import { buildSystemInstruction } from './prompt-builder';

// Mock fs to avoid reading real files
jest.mock('fs');

describe('Prompt Compiler (prompt-builder)', () => {
    const mockFs = fs as jest.Mocked<typeof fs>;
    
    beforeEach(() => {
        jest.resetAllMocks();
    });

    it('should correctly format basic template without skills', () => {
        const result = buildSystemInstruction([], 'This is the template content.');
        expect(result).toContain('<system_instructions>');
        expect(result).toContain('<templates>');
        expect(result).toContain('This is the template content.');
        expect(result).toContain('</templates>');
        expect(result).toContain('</system_instructions>');
        expect(result).not.toContain('<skills>');
    });

    it('should read skills, parse frontmatter, and output wrapped XML', () => {
        mockFs.existsSync.mockReturnValue(true);
        mockFs.readFileSync.mockImplementation((filePath) => {
            if (filePath.toString().includes('sd-test-skill')) {
                return `---\nname: TestSkill\n---\n# The Skill\nThis is a test skill.`;
            }
            return '';
        });

        const result = buildSystemInstruction(['sd-test-skill'], 'Template Content');
        
        expect(result).toContain('<skills>');
        expect(result).toContain('<skill name="sd-test-skill">');
        
        // It should strip the frontmatter but keep the content
        expect(result).not.toContain('name: TestSkill');
        expect(result).toContain('# The Skill');
        expect(result).toContain('This is a test skill.');
        expect(result).toContain('</skill>');
    });

    it('should ignore non-existent skills gracefully', () => {
        mockFs.existsSync.mockReturnValue(false);

        const result = buildSystemInstruction(['missing-skill'], 'Template Content');
        
        // Since skill doesn't exist, skillsXml might just contain the empty skills block
        expect(result).toContain('<skills>');
        expect(result).toContain('</skills>');
        expect(result).not.toContain('<skill name="missing-skill">');
    });
});
