import { Type } from '@google/genai';

export type Layer = 'Domain' | 'Application' | 'Infrastructure' | 'Presentation' | 'Tests' | 'Config';
export type StepType = 'foundation' | 'behavior' | 'wiring' | 'polish' | 'test';
export type Complexity = 'S' | 'M' | 'L';
export type Reversibility = 'trivial' | 'moderate' | 'hard';

export interface PatternRef {
  fileLine: string;
  instruction: string;
}

export interface AtomicTask {
  id: string;
  title: string;
  files: string[];
  layer: Layer;
  stepType: StepType;
  testFiles: string[];
  acceptance: string;
  dependsOn: string[];
  conflictsWith: string[];
  estimatedComplexity: Complexity;
  reversibility: Reversibility;
  patternRefs: PatternRef[];
}

export interface PlanPhase {
  phaseNumber: number;
  title: string;
  description: string;
  taskIds: string[];
}

export interface PlanDocument {
  specId: string;
  phases: PlanPhase[];
  tasks: AtomicTask[];
}

export const PLAN_DOCUMENT_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    specId: { type: Type.STRING },
    phases: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          phaseNumber: { type: Type.INTEGER },
          title: { type: Type.STRING },
          description: { type: Type.STRING },
          taskIds: {
            type: Type.ARRAY,
            items: { type: Type.STRING },
          },
        },
        required: ['phaseNumber', 'title', 'description', 'taskIds'],
      },
    },
    tasks: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          id: { type: Type.STRING },
          title: { type: Type.STRING },
          files: {
            type: Type.ARRAY,
            items: { type: Type.STRING },
          },
          layer: { 
            type: Type.STRING, 
            enum: ['Domain', 'Application', 'Infrastructure', 'Presentation', 'Tests', 'Config'] 
          },
          stepType: { 
            type: Type.STRING, 
            enum: ['foundation', 'behavior', 'wiring', 'polish', 'test'] 
          },
          testFiles: {
            type: Type.ARRAY,
            items: { type: Type.STRING },
          },
          acceptance: { type: Type.STRING },
          dependsOn: {
            type: Type.ARRAY,
            items: { type: Type.STRING },
          },
          conflictsWith: {
            type: Type.ARRAY,
            items: { type: Type.STRING },
          },
          estimatedComplexity: { 
            type: Type.STRING, 
            enum: ['S', 'M', 'L'] 
          },
          reversibility: { 
            type: Type.STRING, 
            enum: ['trivial', 'moderate', 'hard'] 
          },
          patternRefs: {
            type: Type.ARRAY,
            items: {
              type: Type.OBJECT,
              properties: {
                fileLine: { type: Type.STRING },
                instruction: { type: Type.STRING },
              },
              required: ['fileLine', 'instruction'],
            },
          },
        },
        required: [
          'id',
          'title',
          'files',
          'layer',
          'stepType',
          'testFiles',
          'acceptance',
          'dependsOn',
          'conflictsWith',
          'estimatedComplexity',
          'reversibility',
          'patternRefs',
        ],
      },
    },
  },
  required: ['specId', 'phases', 'tasks'],
};
