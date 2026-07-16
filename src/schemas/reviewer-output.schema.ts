import { Type } from '@google/genai';

export interface ReviewerComment {
  file: string;
  line: number;
  severity: 'BLOCK' | 'WARN' | 'SUGGEST';
  comment: string;
}

export interface ReviewerOutput {
  comments: ReviewerComment[];
}

export const REVIEWER_OUTPUT_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    comments: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          file: { type: Type.STRING },
          line: { type: Type.INTEGER },
          severity: {
            type: Type.STRING,
            enum: ['BLOCK', 'WARN', 'SUGGEST'],
          },
          comment: { type: Type.STRING },
        },
        required: ['file', 'line', 'severity', 'comment'],
      },
    },
  },
  required: ['comments'],
};
