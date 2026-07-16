import { PlanDocument, AtomicTask } from '../schemas';

export function renderPlanToMarkdown(doc: PlanDocument): string {
  const sections: string[] = [];

  sections.push(`# Implementation Plan for ${doc.specId}`);

  if (doc.phases && doc.phases.length > 0) {
    for (const phase of doc.phases) {
      let phaseSection = `## Phase ${phase.phaseNumber}: ${phase.title}\n\n${phase.description}`;
      if (phase.taskIds && phase.taskIds.length > 0) {
        phaseSection += `\n\n### Tasks\n`;
        phaseSection += phase.taskIds.map(t => `- [ ] ${t}`).join('\n');
      }
      sections.push(phaseSection);
    }
  } else {
    sections.push(`No phases defined.`);
  }

  return sections.join('\n\n') + '\n';
}

function formatPatternRefs(task: AtomicTask): string {
  if (!task.patternRefs || task.patternRefs.length === 0) {
    return 'none';
  }
  return task.patternRefs.map(r => `${r.fileLine} (${r.instruction})`).join(', ');
}

export function renderTasksToMarkdown(doc: PlanDocument): string {
  const sections: string[] = [];

  sections.push(`# Tasks for ${doc.specId}`);

  if (doc.tasks && doc.tasks.length > 0) {
    for (const task of doc.tasks) {
      let taskSection = `### ${task.id} - ${task.title}\n\n`;
      taskSection += `- **Files**: ${task.files.join(', ')}\n`;
      taskSection += `- **Layer**: ${task.layer}\n`;
      taskSection += `- **Step type**: ${task.stepType}\n`;
      taskSection += `- **Test**: ${task.testFiles.join(', ')}\n`;
      taskSection += `- **Acceptance**: ${task.acceptance}\n`;
      taskSection += `- **Depends on**: ${task.dependsOn && task.dependsOn.length > 0 ? task.dependsOn.join(', ') : 'none'}\n`;
      taskSection += `- **Conflicts with**: ${task.conflictsWith && task.conflictsWith.length > 0 ? task.conflictsWith.join(', ') : 'none'}\n`;
      taskSection += `- **Estimated complexity**: ${task.estimatedComplexity}\n`;
      taskSection += `- **Reversibility**: ${task.reversibility}\n`;
      taskSection += `- **Pattern refs**: ${formatPatternRefs(task)}`;

      sections.push(taskSection);
    }
  } else {
    sections.push(`No tasks defined.`);
  }

  return sections.join('\n\n') + '\n';
}
