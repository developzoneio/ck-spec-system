import { StateMachine, StateChangeEvent } from '../StateMachine';
import { WorkflowState, WorkflowEvent } from '../WorkflowContext';

describe('StateMachine', () => {
  let stateMachine: StateMachine;

  beforeEach(() => {
    stateMachine = new StateMachine('test-wf-1', { ticketId: 'SWA-123' });
  });

  afterEach(() => {
    stateMachine.dispose();
  });

  it('should initialize with correct default state and context', () => {
    expect(stateMachine.currentState).toBe(WorkflowState.Init);
    expect(stateMachine.context.workflowId).toBe('test-wf-1');
    expect(stateMachine.context.ticketId).toBe('SWA-123');
    expect(stateMachine.context.approvalStatus).toBe('none');
    expect(stateMachine.context.filePaths).toEqual([]);
  });

  it('should transition from Init to Drafting on START', () => {
    const listener = jest.fn();
    stateMachine.onStateChange(listener);

    const result = stateMachine.dispatch(WorkflowEvent.START, { metadata: { foo: 'bar' } });

    expect(result).toBe(true);
    expect(stateMachine.currentState).toBe(WorkflowState.Drafting);
    expect(stateMachine.context.metadata).toEqual({ foo: 'bar' });

    expect(listener).toHaveBeenCalledWith({
      previousState: WorkflowState.Init,
      newState: WorkflowState.Drafting,
      context: stateMachine.context
    } as StateChangeEvent);
  });

  it('should transition from Drafting to Pending_Approval on DRAFT_COMPLETE', () => {
    stateMachine.dispatch(WorkflowEvent.START);
    
    const result = stateMachine.dispatch(WorkflowEvent.DRAFT_COMPLETE, { filePaths: ['src/index.ts'] });

    expect(result).toBe(true);
    expect(stateMachine.currentState).toBe(WorkflowState.Pending_Approval);
    expect(stateMachine.context.filePaths).toEqual(['src/index.ts']);
    expect(stateMachine.context.approvalStatus).toBe('pending');
  });

  it('should transition from Pending_Approval to Done on USER_APPROVED', () => {
    stateMachine.dispatch(WorkflowEvent.START);
    stateMachine.dispatch(WorkflowEvent.DRAFT_COMPLETE);
    
    const result = stateMachine.dispatch(WorkflowEvent.USER_APPROVED);

    expect(result).toBe(true);
    expect(stateMachine.currentState).toBe(WorkflowState.Done);
    expect(stateMachine.context.approvalStatus).toBe('approved');
  });

  it('should transition from Pending_Approval back to Drafting on USER_REJECTED', () => {
    stateMachine.dispatch(WorkflowEvent.START);
    stateMachine.dispatch(WorkflowEvent.DRAFT_COMPLETE);
    
    const result = stateMachine.dispatch(WorkflowEvent.USER_REJECTED);

    expect(result).toBe(true);
    expect(stateMachine.currentState).toBe(WorkflowState.Drafting);
    expect(stateMachine.context.approvalStatus).toBe('rejected');
  });

  it('should not transition on invalid events', () => {
    const listener = jest.fn();
    stateMachine.onStateChange(listener);

    // DRAFT_COMPLETE is not valid from Init
    const result = stateMachine.dispatch(WorkflowEvent.DRAFT_COMPLETE);

    expect(result).toBe(false);
    expect(stateMachine.currentState).toBe(WorkflowState.Init);
    expect(listener).not.toHaveBeenCalled();
  });
});
