import { Type } from '@google/genai';

export interface SpecScenario {
  name: string;
  given: string;
  when: string;
  then: string;
}

export interface ConstitutionCheck {
  section: string;
  assessment: string;
}

export interface SpecDocument {
  id: string;
  type: 'feature';
  status: 'draft';
  jira: string;
  created: string;
  title: string;
  why: string;
  scenarios: SpecScenario[];
  successCriteria: string[];
  outOfScope: string[];
  openQuestions: string[];
  constitutionCheck: ConstitutionCheck[];
  riskOfViolation: 'none' | 'low' | 'medium';
  linkedSpecs: {
    dependsOn: string;
    relatedTo: string;
    spawns: string;
  };
}

export const SPEC_DOCUMENT_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    id: { type: Type.STRING },
    type: { type: Type.STRING, enum: ['feature'] },
    status: { type: Type.STRING, enum: ['draft'] },
    jira: { type: Type.STRING },
    created: { type: Type.STRING },
    title: { type: Type.STRING },
    why: { type: Type.STRING },
    scenarios: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          name: { type: Type.STRING },
          given: { type: Type.STRING },
          when: { type: Type.STRING },
          then: { type: Type.STRING },
        },
        required: ['name', 'given', 'when', 'then'],
      },
    },
    successCriteria: {
      type: Type.ARRAY,
      items: { type: Type.STRING },
    },
    outOfScope: {
      type: Type.ARRAY,
      items: { type: Type.STRING },
    },
    openQuestions: {
      type: Type.ARRAY,
      items: { type: Type.STRING },
    },
    constitutionCheck: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          section: { type: Type.STRING },
          assessment: { type: Type.STRING },
        },
        required: ['section', 'assessment'],
      },
    },
    riskOfViolation: { type: Type.STRING, enum: ['none', 'low', 'medium'] },
    linkedSpecs: {
      type: Type.OBJECT,
      properties: {
        dependsOn: { type: Type.STRING },
        relatedTo: { type: Type.STRING },
        spawns: { type: Type.STRING },
      },
      required: ['dependsOn', 'relatedTo', 'spawns'],
    },
  },
  required: [
    'id',
    'type',
    'status',
    'jira',
    'created',
    'title',
    'why',
    'scenarios',
    'successCriteria',
    'outOfScope',
    'openQuestions',
    'constitutionCheck',
    'riskOfViolation',
    'linkedSpecs',
  ],
};
