import * as vscode from 'vscode';
import { WorkflowState, WorkflowEvent, WorkflowContext } from './WorkflowContext';

export interface StateChangeEvent {
  previousState: WorkflowState;
  newState: WorkflowState;
  context: WorkflowContext;
}

export class StateMachine {
  private _currentState: WorkflowState;
  private _context: WorkflowContext;
  
  private _onStateChange = new vscode.EventEmitter<StateChangeEvent>();
  public readonly onStateChange = this._onStateChange.event;

  constructor(workflowId: string, initialContext?: Partial<WorkflowContext>) {
    this._currentState = WorkflowState.Init;
    this._context = {
      workflowId,
      filePaths: [],
      approvalStatus: 'none',
      ...initialContext
    };
  }

  get currentState(): WorkflowState {
    return this._currentState;
  }

  get context(): WorkflowContext {
    return this._context;
  }

  public dispatch(event: WorkflowEvent, payload?: Partial<WorkflowContext>): boolean {
    const previousState = this._currentState;
    let nextState = this._currentState;

    switch (this._currentState) {
      case WorkflowState.Init:
        if (event === WorkflowEvent.START) {
          nextState = WorkflowState.Drafting;
        }
        break;
      
      case WorkflowState.Drafting:
        if (event === WorkflowEvent.DRAFT_COMPLETE) {
          nextState = WorkflowState.Pending_Approval;
          this._context.approvalStatus = 'pending';
        }
        break;
        
      case WorkflowState.Pending_Approval:
        if (event === WorkflowEvent.USER_APPROVED) {
          nextState = WorkflowState.Done;
          this._context.approvalStatus = 'approved';
        } else if (event === WorkflowEvent.USER_REJECTED) {
          nextState = WorkflowState.Drafting;
          this._context.approvalStatus = 'rejected';
        }
        break;
        
      case WorkflowState.Done:
        // No further transitions from Done unless reset (out of scope for now)
        break;
    }

    if (nextState !== previousState) {
      this._currentState = nextState;
      if (payload) {
        this._context = { ...this._context, ...payload };
      }
      this._onStateChange.fire({
        previousState,
        newState: nextState,
        context: this._context
      });
      return true;
    }
    
    return false;
  }

  public dispose() {
    this._onStateChange.dispose();
  }
}
