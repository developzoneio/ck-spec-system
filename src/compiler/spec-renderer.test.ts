import { renderSpecToMarkdown } from './spec-renderer';
import { SpecDocument } from '../schemas';

describe('spec-renderer', () => {
  it('should render a complete spec document', () => {
    const doc: SpecDocument = {
      id: 'FEAT-123',
      type: 'feature',
      status: 'draft',
      jira: 'SWA-8',
      created: '2026-07-05',
      title: 'Test Feature',
      why: 'Because we need it.',
      scenarios: [
        {
          name: 'Happy path',
          given: 'a valid input',
          when: 'the user clicks save',
          then: 'it saves',
        },
      ],
      successCriteria: ['Must save', 'Must be fast'],
      outOfScope: ['No emails'],
      openQuestions: ['What color?'],
      constitutionCheck: [
        { section: '§1.1 Layer rules', assessment: 'Matches domain layer' },
      ],
      riskOfViolation: 'low',
      linkedSpecs: {
        dependsOn: 'FEAT-122',
        relatedTo: 'none',
        spawns: 'none',
      },
    };

    const md = renderSpecToMarkdown(doc);

    expect(md).toContain('id: FEAT-123');
    expect(md).toContain('type: feature');
    expect(md).toContain('# Test Feature');
    expect(md).toContain('## Why\n\nBecause we need it.');
    expect(md).toContain('### Scenario 1: Happy path');
    expect(md).toContain('- **Given** a valid input');
    expect(md).toContain('- [ ] Must save');
    expect(md).toContain('- No emails');
    expect(md).toContain('- What color?');
    expect(md).toContain('- **§1.1 Layer rules**: Matches domain layer');
    expect(md).toContain('- **Risk of violation**: low');
    expect(md).toContain('- Depends on: FEAT-122');
  });

  it('should handle empty arrays', () => {
    const doc: SpecDocument = {
      id: 'FEAT-124',
      type: 'feature',
      status: 'draft',
      jira: 'none',
      created: '2026-07-05',
      title: 'Empty Feature',
      why: 'Just why.',
      scenarios: [],
      successCriteria: [],
      outOfScope: [],
      openQuestions: [],
      constitutionCheck: [],
      riskOfViolation: 'none',
      linkedSpecs: {
        dependsOn: 'none',
        relatedTo: 'none',
        spawns: 'none',
      },
    };

    const md = renderSpecToMarkdown(doc);

    expect(md).toContain('No scenarios provided.');
    expect(md).toContain('- [ ] None provided');
    expect(md).toContain('- None'); // Out of scope, open questions, constitution
    expect(md).toContain('- **Risk of violation**: none');
  });
});
