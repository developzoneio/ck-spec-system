import * as vscode from 'vscode';
import { StateMachine } from './StateMachine';
import { WorkflowState, WorkflowEvent, WorkflowContext } from './WorkflowContext';

export class BugWorkflow extends StateMachine {
  
  constructor(workflowId: string, initialContext?: Partial<WorkflowContext>) {
    super(workflowId, initialContext);
  }

  public override dispatch(event: WorkflowEvent, payload?: Partial<WorkflowContext>): boolean {
    const previousState = this._currentState;
    let nextState = this._currentState;

    switch (this._currentState) {
      case WorkflowState.Init:
        if (event === WorkflowEvent.START) {
          nextState = WorkflowState.RCA_Analysis;
          this.executeRCA();
        }
        break;

      case WorkflowState.RCA_Analysis:
        if (event === WorkflowEvent.RCA_GENERATED) {
          nextState = WorkflowState.Gate_RCA_Approval;
          this._context.approvalStatus = 'pending';
        }
        break;

      case WorkflowState.Gate_RCA_Approval:
        if (event === WorkflowEvent.RCA_APPROVED) {
          nextState = WorkflowState.Failing_Test;
          this._context.approvalStatus = 'approved';
          this.executeFailingTest();
        } else if (event === WorkflowEvent.RCA_REJECTED) {
          nextState = WorkflowState.RCA_Analysis;
          this._context.approvalStatus = 'rejected';
          this.executeRCA();
        }
        break;

      case WorkflowState.Failing_Test:
        if (event === WorkflowEvent.FAILING_TEST_GENERATED) {
          nextState = WorkflowState.Gate_Failing_Test_Visual_Diff;
          this._context.approvalStatus = 'pending';
        }
        break;

      case WorkflowState.Gate_Failing_Test_Visual_Diff:
        if (event === WorkflowEvent.FAILING_TEST_APPROVED) {
          nextState = WorkflowState.Fix_Implementation;
          this._context.approvalStatus = 'approved';
          this.executeFix();
        } else if (event === WorkflowEvent.FAILING_TEST_REJECTED) {
          nextState = WorkflowState.Failing_Test;
          this._context.approvalStatus = 'rejected';
          this.executeFailingTest();
        }
        break;

      case WorkflowState.Fix_Implementation:
        if (event === WorkflowEvent.FIX_GENERATED) {
          nextState = WorkflowState.Gate_Fix_Visual_Diff;
          this._context.approvalStatus = 'pending';
        }
        break;

      case WorkflowState.Gate_Fix_Visual_Diff:
        if (event === WorkflowEvent.FIX_APPROVED) {
          nextState = WorkflowState.Done;
          this._context.approvalStatus = 'approved';
        } else if (event === WorkflowEvent.FIX_REJECTED) {
          nextState = WorkflowState.Fix_Implementation;
          this._context.approvalStatus = 'rejected';
          this.executeFix();
        }
        break;

      case WorkflowState.Done:
        // Final state
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

  // --- Agent execution stubs ---

  private async executeRCA() {
    vscode.window.showInformationMessage('BugWorkflow: Gọi sd-debugger để sinh 00-rca.md');
    // MOCK: wait and dispatch RCA_GENERATED
    setTimeout(() => {
      this._context.filePaths = ['BUG-xxx/00-rca.md']; // Mock filepath
      this.dispatch(WorkflowEvent.RCA_GENERATED);
    }, 1500);
  }

  private async executeFailingTest() {
    vscode.window.showInformationMessage('BugWorkflow: Gọi sd-implementer để viết Failing Test');
    setTimeout(() => {
      this._context.filePaths = ['src/tests/bug-fix.test.ts']; // Mock filepath
      this.dispatch(WorkflowEvent.FAILING_TEST_GENERATED);
    }, 1500);
  }

  private async executeFix() {
    vscode.window.showInformationMessage('BugWorkflow: Gọi sd-implementer để sửa lỗi pass test');
    setTimeout(() => {
      this._context.filePaths = ['src/app.ts']; // Mock filepath
      this.dispatch(WorkflowEvent.FIX_GENERATED);
    }, 1500);
  }
}
