import * as vscode from 'vscode';
import { handleWorkflowCommand } from '../commands/workflow-commands';
import { parseCommandInput } from '../parsers/command-parser';

export function registerChatParticipant(context: vscode.ExtensionContext) {
  const handler: vscode.ChatRequestHandler = async (
    request: vscode.ChatRequest,
    _context: vscode.ChatContext,
    stream: vscode.ChatResponseStream,
    _token: vscode.CancellationToken
  ) => {
    const command = request.command;
    const prompt = request.prompt;

    if (command === 'feature' || command === 'bug' || command === 'refactor') {
      const param = parseCommandInput(prompt);

      if (param) {
        stream.markdown(`Đang bắt đầu quy trình ${command} cho \`${param}\`...\n\n`);
      } else {
        stream.markdown(`Đang bắt đầu quy trình ${command} (sẽ cần bạn cung cấp thêm thông tin)...\n\n`);
      }

      // We call the workflow command handler without awaiting so it can prompt the user if needed
      // without blocking the chat response stream finishing.
      handleWorkflowCommand(command, param).catch(err => {
        console.error('Failed to handle workflow command from chat', err);
      });

      return { metadata: { command } };
    }

    stream.markdown(`Xin chào! Tôi là Specwright Developer Gemini. Bạn có thể gọi tôi với các lệnh \`/feature\`, \`/bug\`, hoặc \`/refactor\` để bắt đầu các quy trình làm việc tương ứng.`);
    return {};
  };

  const chatParticipant = vscode.chat.createChatParticipant('specwright.chat', handler);
  chatParticipant.iconPath = vscode.Uri.joinPath(context.extensionUri, 'src', 'assets', 'icon.png'); // optional

  context.subscriptions.push(chatParticipant);
}
