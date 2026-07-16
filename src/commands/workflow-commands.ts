import * as vscode from 'vscode';
import { StateMachine } from '../orchestrator/StateMachine';
import { WorkflowEvent, WorkflowState } from '../orchestrator/WorkflowContext';
import { promptForTicketIdOrDescription } from '../ui/input-forms';
import { parseCommandInput } from '../parsers/command-parser';
import { ApprovalPanel } from '../ui/approval-panel';

export function registerWorkflowCommands(context: vscode.ExtensionContext) {
  const newFeatureCommand = vscode.commands.registerCommand('specwright.newFeature', async (args?: any) => {
    await handleWorkflowCommand('feature', context, args);
  });

  const fixBugCommand = vscode.commands.registerCommand('specwright.fixBug', async (args?: any) => {
    await handleWorkflowCommand('bug', context, args);
  });

  const refactorCommand = vscode.commands.registerCommand('specwright.refactor', async (args?: any) => {
    await handleWorkflowCommand('refactor', context, args);
  });

  context.subscriptions.push(newFeatureCommand, fixBugCommand, refactorCommand);
}

export async function handleWorkflowCommand(type: string, context: vscode.ExtensionContext, args?: any) {
  let param: string | undefined;

  if (typeof args === 'string') {
    param = parseCommandInput(args);
  }

  if (!param) {
    param = await promptForTicketIdOrDescription(type);
  }

  if (!param) {
    // User cancelled
    return;
  }

  // Start the workflow
  const workflowId = `wf-${Date.now()}`;
  const stateMachine = new StateMachine(workflowId, {
    // For now, we just pass the param as if it's the ticket ID or description
    // In the future, this would fetch from Jira if it looks like an ID
  });

  stateMachine.onStateChange((event) => {
    if (event.newState === WorkflowState.Pending_Approval) {
      const docPath = stateMachine.context.filePaths?.[0];
      if (docPath) {
        ApprovalPanel.show(context, docPath, stateMachine);
      } else {
        vscode.window.showErrorMessage('Specwright: No document found to approve.');
      }
    }
  });

  vscode.window.showInformationMessage(`Specwright: Đang bắt đầu quy trình ${type} cho ${param}...`);
  stateMachine.dispatch(WorkflowEvent.START);
}
