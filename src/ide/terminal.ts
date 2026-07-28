import * as vscode from 'vscode';

/**
 * Mocks running a terminal command in the IDE.
 * In a real implementation, this might use child_process.exec or vscode.tasks.
 * For now, we simulate the command output based on the command string.
 * @param command The terminal command to execute.
 * @returns The stdout of the command.
 */
export async function ide_run_terminal_command(command: string): Promise<string> {
  return new Promise((resolve) => {
    setTimeout(() => {
      vscode.window.showInformationMessage(`Terminal: Running command: ${command}`);
      
      if (command.includes('jest --coverage') || command.includes('dotnet test')) {
        // Mock a coverage check. Let's say coverage is 75% so we can trigger the fail gate.
        resolve('Test coverage is 75% (Below 80% threshold)');
      } else if (command.includes('script/measure_baseline.sh')) {
        resolve('Baseline measurement complete: {"p95": "120ms"}');
      } else {
        resolve('Command executed successfully.');
      }
    }, 1000);
  });
}
