import * as vscode from 'vscode';

export async function promptForTicketIdOrDescription(type: string): Promise<string | undefined> {
  let promptTitle = '';
  let placeHolder = '';

  switch (type) {
    case 'feature':
      promptTitle = 'New Feature';
      placeHolder = 'Enter Jira Ticket ID (e.g. PROJ-123) or short description';
      break;
    case 'bug':
      promptTitle = 'Fix Bug';
      placeHolder = 'Enter Jira Ticket ID for the bug (e.g. PROJ-123)';
      break;
    case 'refactor':
      promptTitle = 'Refactor';
      placeHolder = 'Enter refactoring description';
      break;
    default:
      promptTitle = 'Workflow Parameter';
      placeHolder = 'Enter required parameter';
  }

  const input = await vscode.window.showInputBox({
    title: `Specwright: ${promptTitle}`,
    prompt: `Please provide details for the ${type}`,
    placeHolder: placeHolder,
    ignoreFocusOut: true
  });

  return input;
}
