import { ReviewerAgent, ReviewerAgentConfig } from '../reviewer';
import { ReviewerOutput } from '../../schemas/reviewer-output.schema';

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

describe('ReviewerAgent', () => {
  let agent: ReviewerAgent;

  const mockConfig: ReviewerAgentConfig = {
    apiKey: 'test-api-key',
    model: 'gemini-test',
    skills: ['test-skill']
  };

  const dummyReviewOutput: ReviewerOutput = {
    comments: [
      {
        file: 'src/main.ts',
        line: 10,
        severity: 'BLOCK',
        comment: 'Violates architectural boundary'
      },
      {
        file: 'src/utils.ts',
        line: 25,
        severity: 'WARN',
        comment: 'Missing tests'
      }
    ]
  };

  beforeEach(() => {
    jest.clearAllMocks();
    agent = new ReviewerAgent(mockConfig);
  });

  it('should parse and return reviewer output', async () => {
    mockGenerateContent.mockResolvedValueOnce({
      candidates: [{
        content: {
          parts: [{ text: JSON.stringify(dummyReviewOutput) }]
        }
      }]
    });

    const result = await agent.run('test diff');
    
    expect(result).toEqual(dummyReviewOutput);
    expect(mockGenerateContent).toHaveBeenCalledTimes(1);
  });

  it('should throw an error if JSON parsing fails', async () => {
    mockGenerateContent.mockResolvedValueOnce({
      candidates: [{
        content: {
          parts: [{ text: 'invalid json' }]
        }
      }]
    });

    await expect(agent.run('test diff')).rejects.toThrow('Failed to parse ReviewerAgent output JSON: invalid json');
  });
});
