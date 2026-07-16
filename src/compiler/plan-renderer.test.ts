import { renderPlanToMarkdown, renderTasksToMarkdown } from './plan-renderer';
import { PlanDocument } from '../schemas';

describe('plan-renderer', () => {
  const doc: PlanDocument = {
    specId: 'FEAT-123',
    phases: [
      {
        phaseNumber: 1,
        title: 'Initial Phase',
        description: 'Set up foundations',
        taskIds: ['T01', 'T02'],
      },
    ],
    tasks: [
      {
        id: 'T01',
        title: 'Create schemas',
        files: ['src/schemas/a.ts', 'src/schemas/b.ts'],
        layer: 'Domain',
        stepType: 'foundation',
        testFiles: ['src/schemas/a.test.ts'],
        acceptance: 'Tests pass',
        dependsOn: [],
        conflictsWith: [],
        estimatedComplexity: 'M',
        reversibility: 'trivial',
        patternRefs: [
          { fileLine: 'src/old.ts:10', instruction: 'mirror this' },
        ],
      },
      {
        id: 'T02',
        title: 'Create empty task',
        files: ['src/empty.ts'],
        layer: 'Application',
        stepType: 'behavior',
        testFiles: [],
        acceptance: 'It compiles',
        dependsOn: ['T01'],
        conflictsWith: ['T03'],
        estimatedComplexity: 'S',
        reversibility: 'moderate',
        patternRefs: [],
      },
    ],
  };

  it('should render plan document', () => {
    const md = renderPlanToMarkdown(doc);

    expect(md).toContain('# Implementation Plan for FEAT-123');
    expect(md).toContain('## Phase 1: Initial Phase');
    expect(md).toContain('Set up foundations');
    expect(md).toContain('- [ ] T01');
    expect(md).toContain('- [ ] T02');
  });

  it('should render tasks document', () => {
    const md = renderTasksToMarkdown(doc);

    expect(md).toContain('# Tasks for FEAT-123');
    expect(md).toContain('### T01 - Create schemas');
    expect(md).toContain('- **Files**: src/schemas/a.ts, src/schemas/b.ts');
    expect(md).toContain('- **Layer**: Domain');
    expect(md).toContain('- **Step type**: foundation');
    expect(md).toContain('- **Depends on**: none');
    expect(md).toContain('- **Conflicts with**: none');
    expect(md).toContain('- **Pattern refs**: src/old.ts:10 (mirror this)');

    expect(md).toContain('### T02 - Create empty task');
    expect(md).toContain('- **Depends on**: T01');
    expect(md).toContain('- **Conflicts with**: T03');
    expect(md).toContain('- **Pattern refs**: none');
  });

  it('should handle empty phases and tasks', () => {
    const emptyDoc: PlanDocument = { specId: 'FEAT-999', phases: [], tasks: [] };
    
    expect(renderPlanToMarkdown(emptyDoc)).toContain('No phases defined.');
    expect(renderTasksToMarkdown(emptyDoc)).toContain('No tasks defined.');
  });
});
