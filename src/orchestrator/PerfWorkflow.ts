import * as vscode from 'vscode';
import { StateMachine } from './StateMachine';
import { WorkflowState, WorkflowEvent, WorkflowContext } from './WorkflowContext';
import { ide_run_terminal_command } from '../ide/terminal';

export class PerfWorkflow extends StateMachine {
  
  constructor(workflowId: string, initialContext?: Partial<WorkflowContext>) {
    super(workflowId, initialContext);
  }

  public override dispatch(event: WorkflowEvent, payload?: Partial<WorkflowContext>): boolean {
    const previousState = this._currentState;
    let nextState = this._currentState;

    switch (this._currentState) {
      case WorkflowState.Init:
        if (event === WorkflowEvent.START) {
          nextState = WorkflowState.Baseline_Measurement;
          this.executeBaselineMeasurement();
        }
        break;

      case WorkflowState.Baseline_Measurement:
        if (event === WorkflowEvent.BASELINE_COLLECTED) {
          nextState = WorkflowState.Gate_Baseline_Approval;
          this._context.approvalStatus = 'pending';
        }
        break;

      case WorkflowState.Gate_Baseline_Approval:
        if (event === WorkflowEvent.USER_APPROVED) {
          nextState = WorkflowState.Spec;
          this._context.approvalStatus = 'approved';
          this.executeSpec();
        } else if (event === WorkflowEvent.USER_REJECTED) {
          nextState = WorkflowState.Baseline_Measurement;
          this._context.approvalStatus = 'rejected';
          this.executeBaselineMeasurement();
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
          nextState = WorkflowState.Perf_Implement;
          this._context.approvalStatus = 'approved';
          this._context.currentTaskIndex = 0;
          this.executeImplementLoop();
        } else if (event === WorkflowEvent.PLAN_REJECTED) {
          nextState = WorkflowState.Plan;
          this._context.approvalStatus = 'rejected';
          this.executePlan();
        }
        break;

      case WorkflowState.Perf_Implement:
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
            nextState = WorkflowState.Perf_Implement;
            this.executeImplementLoop();
          } else {
            nextState = WorkflowState.Review;
            this.executeReview();
          }
        } else if (event === WorkflowEvent.TASK_REJECTED) {
          nextState = WorkflowState.Perf_Implement;
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

  private async executeBaselineMeasurement() {
    vscode.window.showInformationMessage('PerfWorkflow: Generating and running script to measure baseline metrics...');
    try {
      const output = await ide_run_terminal_command('sh script/measure_baseline.sh');
      this.dispatch(WorkflowEvent.BASELINE_COLLECTED, {
        metadata: { baselineOutput: output }
      });
    } catch (e) {
      vscode.window.showErrorMessage('PerfWorkflow: Failed to measure baseline.');
    }
  }

  private async executeSpec() {
    vscode.window.showInformationMessage('PerfWorkflow: Calling sd-spec-architect to generate 00-spec.md');
    setTimeout(() => {
      this._context.filePaths = ['/.specs/00-spec.md'];
      this.dispatch(WorkflowEvent.SPEC_GENERATED);
    }, 1500);
  }

  private async executePlan() {
    vscode.window.showInformationMessage('PerfWorkflow: Calling sd-spec-architect to split into 01-plan.md');
    setTimeout(() => {
      this._context.filePaths = ['/.specs/01-plan.md'];
      this._context.tasks = [{ id: 1, desc: 'Perf Optimization Task 1' }];
      this.dispatch(WorkflowEvent.PLAN_GENERATED);
    }, 1500);
  }

  private async executeImplementLoop() {
    const task = this._context.tasks?.[this._context.currentTaskIndex || 0];
    vscode.window.showInformationMessage(`PerfWorkflow: Calling sd-implementer for task ${task?.desc}`);
    setTimeout(() => {
      this.dispatch(WorkflowEvent.IMPLEMENT_TASK_COMPLETE);
    }, 1500);
  }

  private async executeReview() {
    vscode.window.showInformationMessage('PerfWorkflow: Calling sd-reviewer & Linter');
    setTimeout(() => {
      this.dispatch(WorkflowEvent.REVIEW_COMPLETE);
    }, 1500);
  }
}
