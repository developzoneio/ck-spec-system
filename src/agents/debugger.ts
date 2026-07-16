import { GoogleGenAI } from '@google/genai';
import * as fs from 'fs';
import * as path from 'path';

import { buildSystemInstruction } from '../compiler/prompt-builder';

export interface DebuggerAgentConfig {
  apiKey: string;
  model?: string;
  skills?: string[];
  cacheName?: string;
}

export class DebuggerAgent {
  private ai: GoogleGenAI;
  private model: string;
  private skills: string[];
  private cacheName?: string;

  constructor(config: DebuggerAgentConfig) {
    this.ai = new GoogleGenAI({ apiKey: config.apiKey });
    this.model = config.model || 'gemini-1.5-pro';
    this.skills = config.skills || ['sd-hypothesis-tree', 'sd-evidence-citation'];
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

  public async run(stacktraceOrProblem: string): Promise<string> {
    const systemInstruction = this.getSystemInstruction();
    
    const config: any = {
      systemInstruction: {
        parts: [{ text: systemInstruction }]
      },
      temperature: 0.1
    };

    if (this.cacheName) {
      config.cachedContent = this.cacheName;
    }

    const userPrompt = `You are an expert debugger and root-cause analysis agent.
Using the codebase context and the skills injected, analyze the following problem or stacktrace.
Output a clear, formatted markdown response detailing your hypotheses, evidence (with file:line citations), and conclusion.

Problem / Stacktrace:
\`\`\`
${stacktraceOrProblem}
\`\`\``;

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

    return textPart.text;
  }
}
