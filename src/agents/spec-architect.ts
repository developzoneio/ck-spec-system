import { GoogleGenAI } from '@google/genai';
import * as fs from 'fs';
import * as path from 'path';

import { buildSystemInstruction } from '../compiler/prompt-builder';
import { SpecDocument, PLAN_DOCUMENT_SCHEMA, SPEC_DOCUMENT_SCHEMA, PlanDocument, SetupFormData } from '../schemas';
import { IDE_READ_FILE_DECLARATION, IDE_LIST_DIRECTORY_DECLARATION, IDE_SEARCH_TEXT_DECLARATION } from '../tools/ide-tools.declarations';
import { IdeToolHandlers } from '../tools/ide-tools.handlers';

export interface ArchitectAgentConfig {
  apiKey: string;
  model?: string;
  skills?: string[];
  cacheName?: string;
}

export interface ArchitectResult {
  spec: SpecDocument;
  plan: PlanDocument;
}

export class SpecArchitectAgent {
  private ai: GoogleGenAI;
  private model: string;
  private skills: string[];
  private cacheName?: string;
  private toolHandlers: IdeToolHandlers;

  private static READ_ONLY_TOOLS = [
    IDE_READ_FILE_DECLARATION,
    IDE_LIST_DIRECTORY_DECLARATION,
    IDE_SEARCH_TEXT_DECLARATION,
  ];

  constructor(config: ArchitectAgentConfig, toolHandlers: IdeToolHandlers) {
    this.ai = new GoogleGenAI({ apiKey: config.apiKey });
    this.model = config.model || 'gemini-2.5-pro';
    this.skills = config.skills || ['sd-atomic-task-format', 'sd-spec-templates', 'sd-pattern-discipline'];
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

  private getConstitutionTemplate(): string {
    const assetsDir = path.resolve(__dirname, '..', 'assets', 'templates');
    const templatePath = path.join(assetsDir, 'GEMINI_CONSTITUTION.template.md');

    if (fs.existsSync(templatePath)) {
      return fs.readFileSync(templatePath, 'utf8');
    }

    return '';
  }

  private async runPass<T>(prompt: string, schema: any, contextMessages: any[] = []): Promise<{ result: T, messages: any[] }> {
    const systemInstruction = this.getSystemInstruction();
    
    const config: any = {
      systemInstruction: {
        parts: [{ text: systemInstruction }]
      },
      tools: [{ functionDeclarations: SpecArchitectAgent.READ_ONLY_TOOLS }],
      responseMimeType: 'application/json',
      responseSchema: schema,
      temperature: 0.2
    };

    if (this.cacheName) {
      config.cachedContent = this.cacheName;
    }

    const messages = [...contextMessages, { role: 'user', parts: [{ text: prompt }] }];
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
          isComplete = true;
        } else {
           isComplete = true; 
        }
      }
    }
    
    if (!finalResponseText) {
      throw new Error("Model finished without providing a text response.");
    }

    try {
      const result = JSON.parse(finalResponseText) as T;
      return { result, messages };
    } catch (e) {
      throw new Error(`Failed to parse JSON response: ${finalResponseText}`);
    }
  }

  public async run(userPrompt: string): Promise<ArchitectResult> {
    // Pass 1: Generate Spec
    const specPrompt = `Task: Analyze the request and generate a Spec document.\nRequest: ${userPrompt}\n\nPlease explore the codebase if necessary to understand the context before generating the spec. Ensure the response strictly follows the provided JSON schema.`;
    const { result: spec, messages: specMessages } = await this.runPass<SpecDocument>(specPrompt, SPEC_DOCUMENT_SCHEMA);

    // Pass 2: Generate Plan
    const planPrompt = `Task: Based on the Spec generated, create an Implementation Plan.\n\nGenerate a detailed plan with phases and atomic tasks that adhere to the sd-atomic-task-format skill. Ensure the response strictly follows the provided JSON schema.`;
    const { result: plan } = await this.runPass<PlanDocument>(planPrompt, PLAN_DOCUMENT_SCHEMA, specMessages);

    return { spec, plan };
  }

  /**
   * Generates a personalized GEMINI_CONSTITUTION.md using the Gemini API.
   * Takes setup form data (tech stack, framework, team rules) and produces
   * a filled-in constitution markdown tailored to the project.
   */
  public async generateConstitution(formData: SetupFormData): Promise<string> {
    const template = this.getConstitutionTemplate();

    const prompt = `You are a senior software architect. Generate a complete, filled-in GEMINI_CONSTITUTION.md file for a project with the following setup:

Project Name: ${formData.projectName}
Language: ${formData.language}
Framework: ${formData.framework}
Database: ${formData.database || 'Not specified'}
Shell: ${formData.shell}

Team-specific coding rules and conventions:
${formData.teamRules || 'No specific rules provided.'}

Use the following template as the structure. Replace ALL <<placeholder>> tokens with appropriate values based on the project setup. Keep the Specwright workflow table and "Read on demand" section exactly as-is. Fill in the Stack, Commands, Architecture, Code conventions, Forbidden patterns, and Quality bars sections with best-practice defaults for the specified tech stack, merged with any team rules provided above.

--- TEMPLATE START ---
${template}
--- TEMPLATE END ---

Output ONLY the final markdown content. Do not wrap it in code fences. Do not include any explanation before or after the markdown.`;

    const systemInstruction = 'You are a technical documentation generator for the Specwright spec-driven development system. You produce clean, production-ready markdown files.';

    const config: any = {
      systemInstruction: {
        parts: [{ text: systemInstruction }]
      },
      temperature: 0.3,
    };

    const response = await this.ai.models.generateContent({
      model: this.model,
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      config,
    } as any);

    const responseText = response.candidates?.[0]?.content?.parts?.find((p: any) => p.text)?.text;

    if (!responseText) {
      throw new Error('No content returned from model for constitution generation.');
    }

    return responseText.trim();
  }
}

