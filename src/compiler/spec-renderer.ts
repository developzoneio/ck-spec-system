import { SpecDocument } from '../schemas';

export function renderSpecToMarkdown(doc: SpecDocument): string {
  const sections: string[] = [];

  // Frontmatter
  sections.push(`---
id: ${doc.id}
type: ${doc.type}
status: ${doc.status}
jira: ${doc.jira}
created: ${doc.created}
---`);

  // Title
  sections.push(`# ${doc.title}`);

  // Why
  sections.push(`## Why\n\n${doc.why}`);

  // What (Scenarios)
  let whatSection = `## What`;
  if (doc.scenarios && doc.scenarios.length > 0) {
    for (let i = 0; i < doc.scenarios.length; i++) {
      const s = doc.scenarios[i];
      whatSection += `\n\n### Scenario ${i + 1}: ${s.name}\n\n`;
      whatSection += `- **Given** ${s.given}\n`;
      whatSection += `- **When** ${s.when}\n`;
      whatSection += `- **Then** ${s.then}`;
    }
  } else {
    whatSection += `\n\nNo scenarios provided.`;
  }
  sections.push(whatSection);

  // Success criteria
  let criteriaSection = `## Success criteria`;
  if (doc.successCriteria && doc.successCriteria.length > 0) {
    criteriaSection += `\n\n` + doc.successCriteria.map(c => `- [ ] ${c}`).join('\n');
  } else {
    criteriaSection += `\n\n- [ ] None provided`;
  }
  sections.push(criteriaSection);

  // Out of scope
  let outOfScopeSection = `## Out of scope`;
  if (doc.outOfScope && doc.outOfScope.length > 0) {
    outOfScopeSection += `\n\n` + doc.outOfScope.map(o => `- ${o}`).join('\n');
  } else {
    outOfScopeSection += `\n\n- None`;
  }
  sections.push(outOfScopeSection);

  // Open questions
  let openQuestionsSection = `## Open questions`;
  if (doc.openQuestions && doc.openQuestions.length > 0) {
    openQuestionsSection += `\n\n` + doc.openQuestions.map(q => `- ${q}`).join('\n');
  } else {
    openQuestionsSection += `\n\n- None`;
  }
  sections.push(openQuestionsSection);

  // Constitution check
  let constSection = `## Constitution check`;
  if (doc.constitutionCheck && doc.constitutionCheck.length > 0) {
    constSection += `\n\n` + doc.constitutionCheck.map(c => `- **${c.section}**: ${c.assessment}`).join('\n');
  } else {
    constSection += `\n\n- None`;
  }
  constSection += `\n- **Risk of violation**: ${doc.riskOfViolation}`;
  sections.push(constSection);

  // Linked specs
  let linkedSection = `## Linked specs`;
  const deps = doc.linkedSpecs?.dependsOn || 'none';
  const rels = doc.linkedSpecs?.relatedTo || 'none';
  const spawns = doc.linkedSpecs?.spawns || 'none';
  linkedSection += `\n\n- Depends on: ${deps}\n- Related to: ${rels}\n- Spawns: ${spawns}`;
  sections.push(linkedSection);

  return sections.join('\n\n') + '\n';
}
