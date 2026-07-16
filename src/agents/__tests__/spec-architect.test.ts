import { SpecArchitectAgent, ArchitectAgentConfig } from '../spec-architect';
import { IdeToolHandlers } from '../../tools/ide-tools.handlers';
import { SpecDocument, PlanDocument } from '../../schemas';

// Mock the prompt builder so we don't need real files
jest.mock('../../compiler/prompt-builder', () => ({
  buildSystemInstruction: jest.fn().mockReturnValue('mocked system instruction')
}));

// Mock @google/genai
const mockGenerateContent = jest.fn();
jest.mock('@google/genai', () => ({
  GoogleGenAI: jest.fn().mockImplementation(() => ({
    models: {
      generateContent: mockGenerateContent
    }
  })),
  Type: {
    STRING: 'STRING',
    NUMBER: 'NUMBER',
    INTEGER: 'INTEGER',
    BOOLEAN: 'BOOLEAN',
    ARRAY: 'ARRAY',
    OBJECT: 'OBJECT'
  }
}));

describe('SpecArchitectAgent', () => {
  let agent: SpecArchitectAgent;
  let mockToolHandlers: jest.Mocked<IdeToolHandlers>;

  const mockConfig: ArchitectAgentConfig = {
    apiKey: 'test-api-key',
    model: 'gemini-test',
    skills: ['test-skill']
  };

  const dummySpec: SpecDocument = {
    id: 'test-spec',
    type: 'feature',
    status: 'draft',
    jira: 'SWA-14',
    created: '2026-07-01',
    title: 'Test Feature',
    why: 'Because',
    scenarios: [],
    successCriteria: [],
    outOfScope: [],
    openQuestions: [],
    constitutionCheck: [],
    riskOfViolation: 'none',
    linkedSpecs: { dependsOn: '', relatedTo: '', spawns: '' }
  };

  const dummyPlan: PlanDocument = {
    specId: 'test-spec',
    phases: [],
    tasks: []
  };

  beforeEach(() => {
    jest.clearAllMocks();
    
    mockToolHandlers = {
      dispatch: jest.fn()
    } as any;

    agent = new SpecArchitectAgent(mockConfig, mockToolHandlers);
  });

  it('should generate Spec and Plan sequentially', async () => {
    // Pass 1: Spec generation
    mockGenerateContent.mockResolvedValueOnce({
      candidates: [{
        content: {
          parts: [{ text: JSON.stringify(dummySpec) }]
        }
      }]
    });

    // Pass 2: Plan generation
    mockGenerateContent.mockResolvedValueOnce({
      candidates: [{
        content: {
          parts: [{ text: JSON.stringify(dummyPlan) }]
        }
      }]
    });

    const result = await agent.run('test prompt');
    
    expect(result.spec).toEqual(dummySpec);
    expect(result.plan).toEqual(dummyPlan);
    expect(mockGenerateContent).toHaveBeenCalledTimes(2);
  });

  it('should handle tool calls correctly during generation', async () => {
    // Setup Pass 1 (Spec) to do one tool call then return text
    mockGenerateContent.mockResolvedValueOnce({
      candidates: [{
        content: {
          parts: [{
            functionCall: {
              name: 'ide_read_file',
              args: { path: 'test.ts' }
            }
          }]
        }
      }]
    });

    mockToolHandlers.dispatch.mockResolvedValueOnce('file content here');

    mockGenerateContent.mockResolvedValueOnce({
      candidates: [{
        content: {
          parts: [{ text: JSON.stringify(dummySpec) }]
        }
      }]
    });

    // Setup Pass 2 (Plan) to just return text directly
    mockGenerateContent.mockResolvedValueOnce({
      candidates: [{
        content: {
          parts: [{ text: JSON.stringify(dummyPlan) }]
        }
      }]
    });

    const result = await agent.run('test tool calls');

    expect(result.spec).toEqual(dummySpec);
    expect(mockToolHandlers.dispatch).toHaveBeenCalledWith('ide_read_file', { path: 'test.ts' });
    expect(mockGenerateContent).toHaveBeenCalledTimes(3); // 2 for Pass 1, 1 for Pass 2
  });

  it('should throw an error if JSON parsing fails', async () => {
    mockGenerateContent.mockResolvedValueOnce({
      candidates: [{
        content: {
          parts: [{ text: 'invalid json' }]
        }
      }]
    });

    await expect(agent.run('test error')).rejects.toThrow('Failed to parse JSON response: invalid json');
  });

  it('should handle tool call errors gracefully by passing them to the model', async () => {
    // Setup Pass 1 to do a tool call that fails
    mockGenerateContent.mockResolvedValueOnce({
      candidates: [{
        content: {
          parts: [{
            functionCall: {
              name: 'ide_list_directory',
              args: { path: 'invalid/path' }
            }
          }]
        }
      }]
    });

    mockToolHandlers.dispatch.mockRejectedValueOnce(new Error('Directory not found'));

    // The agent loops back to model with the error
    mockGenerateContent.mockResolvedValueOnce({
      candidates: [{
        content: {
          parts: [{ text: JSON.stringify(dummySpec) }]
        }
      }]
    });

    // Setup Pass 2
    mockGenerateContent.mockResolvedValueOnce({
      candidates: [{
        content: {
          parts: [{ text: JSON.stringify(dummyPlan) }]
        }
      }]
    });

    const result = await agent.run('test error loop');
    expect(result.spec).toEqual(dummySpec);
    expect(mockToolHandlers.dispatch).toHaveBeenCalledWith('ide_list_directory', { path: 'invalid/path' });
    
    // We can't easily assert on the exact functionResponse sent back, but we know it called generateContent again
    expect(mockGenerateContent).toHaveBeenCalledTimes(3);
  });
});
