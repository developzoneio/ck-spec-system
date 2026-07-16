import { GoogleGenAI } from '@google/genai';
import * as fs from 'fs';
import * as path from 'path';

import { buildSystemInstruction } from '../compiler/prompt-builder';
import { REVIEWER_OUTPUT_SCHEMA, ReviewerOutput } from '../schemas/reviewer-output.schema';

export interface ReviewerAgentConfig {
  apiKey: string;
  model?: string;
  skills?: string[];
  cacheName?: string;
}

export class ReviewerAgent {
  private ai: GoogleGenAI;
  private model: string;
  private skills: string[];
  private cacheName?: string;

  constructor(config: ReviewerAgentConfig) {
    this.ai = new GoogleGenAI({ apiKey: config.apiKey });
    this.model = config.model || 'gemini-1.5-pro';
    this.skills = config.skills || ['sd-severity-taxonomy', 'sd-pattern-discipline'];
    this.cacheName = config.cacheName;
  }

  private getSystemInstruction(): string {
    const assetsDir = path.resolve(__dirname, '..', 'assets');
    const constitutionPath = path.join(assetsDir, 'GEMINI_CONSTITUTION.md');
    let template = '';
    
    if (fs.existsSync(constitutionPath)) {
      template = fs.readFileSync(constitutionPath, 'utf8');
    }

    return buildSystemInstruction(this.skills, template);
  }

  public async run(diffCode: string, specContent?: string): Promise<ReviewerOutput> {
    const systemInstruction = this.getSystemInstruction();
    
    const config: any = {
      systemInstruction: {
        parts: [{ text: systemInstruction }]
      },
      responseMimeType: 'application/json',
      responseSchema: REVIEWER_OUTPUT_SCHEMA,
      temperature: 0.1
    };

    if (this.cacheName) {
      config.cachedContent = this.cacheName;
    }

    const specContext = specContent ? `\n\nReference Spec Content:\n${specContent}` : '';
    const userPrompt = `You are an independent code reviewer. Review the following code diff against the Spec files and GEMINI_CONSTITUTION.md.
Identify design violations, convention drifts, or implementation errors. 
Ensure you classify each finding with the correct severity (BLOCK, WARN, SUGGEST) using the rules in 'sd-severity-taxonomy'.

Code Diff to Review:
\`\`\`diff
${diffCode}
\`\`\`${specContext}`;

    const response = await this.ai.models.generateContent({
      model: this.model,
      contents: [{ role: 'user', parts: [{ text: userPrompt }] }],
      config
    } as any);

    const responseMessage = response.candidates?.[0]?.content;
    if (!responseMessage) {
      throw new Error('No content returned from model');
    }

    const textPart = responseMessage.parts?.find((p: any) => p.text);
    if (!textPart || !textPart.text) {
      throw new Error('Model finished without providing a text response.');
    }

    try {
      return JSON.parse(textPart.text) as ReviewerOutput;
    } catch (e) {
      throw new Error(`Failed to parse ReviewerAgent output JSON: ${textPart.text}`);
    }
  }
}
