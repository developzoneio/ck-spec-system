import * as vscode from 'vscode';
import { StateMachine } from './StateMachine';
import { WorkflowState, WorkflowEvent, WorkflowContext } from './WorkflowContext';
import { ide_run_terminal_command } from '../ide/terminal';

export class RefactorWorkflow extends StateMachine {
  
  constructor(workflowId: string, initialContext?: Partial<WorkflowContext>) {
    super(workflowId, initialContext);
  }

  public override dispatch(event: WorkflowEvent, payload?: Partial<WorkflowContext>): boolean {
    const previousState = this._currentState;
    let nextState = this._currentState;

    switch (this._currentState) {
      case WorkflowState.Init:
        if (event === WorkflowEvent.START) {
          nextState = WorkflowState.Coverage_Check;
          this.executeCoverageCheck();
        }
        break;

      case WorkflowState.Coverage_Check:
        if (event === WorkflowEvent.COVERAGE_CHECK_PASSED) {
          nextState = WorkflowState.Spec; // Proceed to spec generation
          this.executeSpec();
        } else if (event === WorkflowEvent.COVERAGE_CHECK_FAILED) {
          nextState = WorkflowState.Gate_Coverage_Fail;
          this._context.approvalStatus = 'pending';
        }
        break;

      case WorkflowState.Gate_Coverage_Fail:
        if (event === WorkflowEvent.USER_APPROVED || event === WorkflowEvent.USER_REJECTED) {
          // If user acknowledges the failure, we might abort or retry.
          // For now, let's just retry coverage check if approved, or abort if rejected.
          if (event === WorkflowEvent.USER_APPROVED) {
            nextState = WorkflowState.Coverage_Check;
            this.executeCoverageCheck();
          } else {
            nextState = WorkflowState.Done;
          }
        }
        break;

      case WorkflowState.Spec:
        if (event === WorkflowEvent.SPEC_GENERATED) {
          nextState = WorkflowState.Gate1_Spec_Approval;
          this._context.approvalStatus = 'pending';
        }
        break;

      case WorkflowState.Gate1_Spec_Approval:
        if (event === WorkflowEvent.SPEC_APPROVED) {
          nextState = WorkflowState.Plan;
          this._context.approvalStatus = 'approved';
          this.executePlan();
        } else if (event === WorkflowEvent.SPEC_REJECTED) {
          nextState = WorkflowState.Spec;
          this._context.approvalStatus = 'rejected';
          this.executeSpec();
        }
        break;

      case WorkflowState.Plan:
        if (event === WorkflowEvent.PLAN_GENERATED) {
          nextState = WorkflowState.Gate2_Plan_Approval;
          this._context.approvalStatus = 'pending';
        }
        break;

      case WorkflowState.Gate2_Plan_Approval:
        if (event === WorkflowEvent.PLAN_APPROVED) {
          nextState = WorkflowState.Refactor_Implement;
          this._context.approvalStatus = 'approved';
          this._context.currentTaskIndex = 0;
          this.executeImplementLoop();
        } else if (event === WorkflowEvent.PLAN_REJECTED) {
          nextState = WorkflowState.Plan;
          this._context.approvalStatus = 'rejected';
          this.executePlan();
        }
        break;

      case WorkflowState.Refactor_Implement:
        if (event === WorkflowEvent.IMPLEMENT_TASK_COMPLETE) {
          nextState = WorkflowState.Gate3_Visual_Diff;
          this._context.approvalStatus = 'pending';
        } else if (event === WorkflowEvent.ALL_TASKS_COMPLETE) {
          nextState = WorkflowState.Review;
          this.executeReview();
        }
        break;

      case WorkflowState.Gate3_Visual_Diff:
        if (event === WorkflowEvent.TASK_APPROVED) {
          this._context.approvalStatus = 'approved';
          const tasks = this._context.tasks || [];
          const currentIndex = this._context.currentTaskIndex || 0;
          
          if (currentIndex + 1 < tasks.length) {
            this._context.currentTaskIndex = currentIndex + 1;
            nextState = WorkflowState.Refactor_Implement;
            this.executeImplementLoop();
          } else {
            nextState = WorkflowState.Review;
            this.executeReview();
          }
        } else if (event === WorkflowEvent.TASK_REJECTED) {
          nextState = WorkflowState.Refactor_Implement;
          this._context.approvalStatus = 'rejected';
          this.executeImplementLoop(); // re-run current task
        }
        break;

      case WorkflowState.Review:
        if (event === WorkflowEvent.REVIEW_COMPLETE) {
          nextState = WorkflowState.Done;
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

  private async executeCoverageCheck() {
    vscode.window.showInformationMessage('RefactorWorkflow: Checking test coverage > 80%');
    try {
      const output = await ide_run_terminal_command('jest --coverage');
      if (output.includes('Below 80%')) {
        this.dispatch(WorkflowEvent.COVERAGE_CHECK_FAILED, {
           metadata: { coverageError: 'Coverage is below 80%. Please write more tests.' }
        });
      } else {
        this.dispatch(WorkflowEvent.COVERAGE_CHECK_PASSED);
      }
    } catch (e) {
       this.dispatch(WorkflowEvent.COVERAGE_CHECK_FAILED);
    }
  }

  private async executeSpec() {
    vscode.window.showInformationMessage('RefactorWorkflow: Calling sd-spec-architect to generate 00-spec.md');
    setTimeout(() => {
      this._context.filePaths = ['/.specs/00-spec.md'];
      this.dispatch(WorkflowEvent.SPEC_GENERATED);
    }, 1500);
  }

  private async executePlan() {
    vscode.window.showInformationMessage('RefactorWorkflow: Calling sd-spec-architect to split into 01-plan.md');
    setTimeout(() => {
      this._context.filePaths = ['/.specs/01-plan.md'];
      this._context.tasks = [{ id: 1, desc: 'Refactor Task 1' }];
      this.dispatch(WorkflowEvent.PLAN_GENERATED);
    }, 1500);
  }

  private async executeImplementLoop() {
    const task = this._context.tasks?.[this._context.currentTaskIndex || 0];
    vscode.window.showInformationMessage(`RefactorWorkflow: Calling sd-implementer for task ${task?.desc}`);
    setTimeout(() => {
      this.dispatch(WorkflowEvent.IMPLEMENT_TASK_COMPLETE);
    }, 1500);
  }

  private async executeReview() {
    vscode.window.showInformationMessage('RefactorWorkflow: Calling sd-reviewer & Linter');
    setTimeout(() => {
      this.dispatch(WorkflowEvent.REVIEW_COMPLETE);
    }, 1500);
  }
}
