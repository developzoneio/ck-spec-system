import { Type } from '@google/genai';
import { SPEC_DOCUMENT_SCHEMA, PLAN_DOCUMENT_SCHEMA } from './index';

describe('Schema validation', () => {
  it('SPEC_DOCUMENT_SCHEMA should be a valid schema structure', () => {
    expect(SPEC_DOCUMENT_SCHEMA.type).toBe(Type.OBJECT);
    expect(SPEC_DOCUMENT_SCHEMA.properties).toBeDefined();
    
    // Check some required fields
    const req = SPEC_DOCUMENT_SCHEMA.required || [];
    expect(req).toContain('id');
    expect(req).toContain('type');
    expect(req).toContain('scenarios');
    
    // Check nested structures
    const scenarios = SPEC_DOCUMENT_SCHEMA.properties?.scenarios as any;
    expect(scenarios.type).toBe(Type.ARRAY);
    expect(scenarios.items.type).toBe(Type.OBJECT);
    expect(scenarios.items.required).toContain('given');
  });

  it('PLAN_DOCUMENT_SCHEMA should be a valid schema structure', () => {
    expect(PLAN_DOCUMENT_SCHEMA.type).toBe(Type.OBJECT);
    expect(PLAN_DOCUMENT_SCHEMA.properties).toBeDefined();

    const req = PLAN_DOCUMENT_SCHEMA.required || [];
    expect(req).toContain('specId');
    expect(req).toContain('phases');
    expect(req).toContain('tasks');

    // Check nested tasks structure
    const tasks = PLAN_DOCUMENT_SCHEMA.properties?.tasks as any;
    expect(tasks.type).toBe(Type.ARRAY);
    expect(tasks.items.type).toBe(Type.OBJECT);
    
    const taskReq = tasks.items.required;
    expect(taskReq).toContain('id');
    expect(taskReq).toContain('layer');
    expect(taskReq).toContain('stepType');
  });
});
