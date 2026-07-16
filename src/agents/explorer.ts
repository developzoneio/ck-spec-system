import { GoogleGenAI } from '@google/genai';
import * as fs from 'fs';
import * as path from 'path';

import { buildSystemInstruction } from '../compiler/prompt-builder';
import { IDE_READ_FILE_DECLARATION, IDE_LIST_DIRECTORY_DECLARATION } from '../tools/ide-tools.declarations';
import { IdeToolHandlers } from '../tools/ide-tools.handlers';

export interface ExplorerAgentConfig {
  apiKey: string;
  model?: string;
  skills?: string[];
  cacheName?: string;
}

export class ExplorerAgent {
  private ai: GoogleGenAI;
  private model: string;
  private skills: string[];
  private cacheName?: string;
  private toolHandlers: IdeToolHandlers;

  private static READ_ONLY_TOOLS = [
    IDE_READ_FILE_DECLARATION,
    IDE_LIST_DIRECTORY_DECLARATION,
  ];

  constructor(config: ExplorerAgentConfig, toolHandlers: IdeToolHandlers) {
    this.ai = new GoogleGenAI({ apiKey: config.apiKey });
    this.model = config.model || 'gemini-1.5-flash';
    this.skills = config.skills || [];
    this.cacheName = config.cacheName;
    this.toolHandlers = toolHandlers;
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

  public async run(query: string): Promise<string> {
    const systemInstruction = this.getSystemInstruction();
    
    const config: any = {
      systemInstruction: {
        parts: [{ text: systemInstruction }]
      },
      tools: [{ functionDeclarations: ExplorerAgent.READ_ONLY_TOOLS }],
      temperature: 0.1
    };

    if (this.cacheName) {
      config.cachedContent = this.cacheName;
    }

    const messages: any[] = [{ role: 'user', parts: [{ text: `Task: Answer the following query by exploring the codebase using the provided tools.\n\nQuery: ${query}` }] }];
    let isComplete = false;
    let finalResponseText = '';

    while (!isComplete) {
      const response = await this.ai.models.generateContent({
        model: this.model,
        contents: messages,
        config
      } as any);

      const responseMessage = response.candidates?.[0]?.content;
      if (!responseMessage) {
        throw new Error('No content returned from model');
      }

      messages.push(responseMessage);

      const functionCalls = responseMessage.parts?.filter((p: any) => p.functionCall);
      
      if (functionCalls && functionCalls.length > 0) {
        const functionResponses = [];
        
        for (const callPart of functionCalls) {
          const call = callPart.functionCall;
          if (!call || !call.name) continue;

          try {
            const resultText = await this.toolHandlers.dispatch(call.name, (call.args || {}) as Record<string, unknown>);
            functionResponses.push({
              functionResponse: {
                name: call.name,
                response: { result: resultText }
              }
            });
          } catch (e: any) {
            functionResponses.push({
              functionResponse: {
                name: call.name,
                response: { error: e.message || 'Unknown error occurred' }
              }
            });
          }
        }
        
        messages.push({
          role: 'user',
          parts: functionResponses
        });
      } else {
        const textPart = responseMessage.parts?.find((p: any) => p.text);
        if (textPart && textPart.text) {
          finalResponseText = textPart.text;
        }
        isComplete = true; 
      }
    }
    
    if (!finalResponseText) {
      throw new Error("Model finished without providing a text response.");
    }

    return finalResponseText;
  }
}
