import * as fs from 'fs';
import * as path from 'path';
import matter from 'gray-matter';

/**
 * Builds a system instruction prompt by combining a base template and a set of requested skills.
 * 
 * @param skills Array of skill folder names to include (e.g., ['sd-hypothesis-tree', 'sd-atomic-task-format'])
 * @param template The base template content or system instructions
 * @returns A formatted XML string
 */
export function buildSystemInstruction(skills: string[], template: string): string {
    const assetsDir = path.resolve(__dirname, '..', 'assets');
    const skillsDir = path.join(assetsDir, 'skills');

    let skillsXml = '';

    if (skills && skills.length > 0) {
        skillsXml = '\n  <skills>\n';
        for (const skill of skills) {
            const skillFilePath = path.join(skillsDir, skill, 'SKILL.md');
            if (fs.existsSync(skillFilePath)) {
                const fileContent = fs.readFileSync(skillFilePath, 'utf-8');
                
                // Use gray-matter to parse and remove frontmatter
                const parsed = matter(fileContent);
                const body = parsed.content.trim();

                // Indent the body slightly for better XML readability
                const indentedBody = body.split('\n').map(line => `      ${line}`).join('\n');

                skillsXml += `    <skill name="${skill}">\n${indentedBody}\n    </skill>\n`;
            } else {
                console.warn(`Skill file not found: ${skillFilePath}`);
            }
        }
        skillsXml += '  </skills>\n';
    }

    return `<system_instructions>
  <templates>
${template.split('\n').map(line => `    ${line}`).join('\n')}
  </templates>${skillsXml}</system_instructions>`;
}
