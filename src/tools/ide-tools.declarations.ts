import { Type } from '@google/genai';

export const IDE_READ_FILE_DECLARATION = {
  name: 'ide_read_file',
  description: 'Reads file content from the workspace. Automatically prevents reading binary files and respects a maximum file size limit to preserve context.',
  parameters: {
    type: Type.OBJECT,
    properties: {
      path: {
        type: Type.STRING,
        description: 'The path of the file to read, relative to the workspace root.',
      },
      startLine: {
        type: Type.INTEGER,
        description: 'Optional. The 1-indexed starting line number to read. If not provided, reads from the beginning of the file.',
      },
      endLine: {
        type: Type.INTEGER,
        description: 'Optional. The 1-indexed ending line number to read. If not provided, reads until the end of the file.',
      },
    },
    required: ['path'],
  },
};

export const IDE_LIST_DIRECTORY_DECLARATION = {
  name: 'ide_list_directory',
  description: 'Lists the contents (files and subdirectories) of a directory within the workspace. Useful for exploring project structure when exact paths are unknown.',
  parameters: {
    type: Type.OBJECT,
    properties: {
      path: {
        type: Type.STRING,
        description: 'The directory path to list, relative to the workspace root. Use "." for the root directory.',
      },
    },
    required: ['path'],
  },
};

export const IDE_SEARCH_TEXT_DECLARATION = {
  name: 'ide_search_text',
  description: 'Searches for text within workspace files using a query and a file glob pattern. This tool is fast and respects .gitignore automatically. It caps results to prevent flooding the context.',
  parameters: {
    type: Type.OBJECT,
    properties: {
      query: {
        type: Type.STRING,
        description: 'The literal string or regex pattern to search for within file contents.',
      },
      pattern: {
        type: Type.STRING,
        description: 'A file glob pattern to filter which files to search (e.g., "**/*.ts", "src/components/**/*.tsx"). Use "**/*" to search all files.',
      },
    },
    required: ['query', 'pattern'],
  },
};

export const IDE_APPLY_DIFF_DECLARATION = {
  name: 'ide_apply_diff',
  description: 'Applies a search/replace diff to a file and opens a diff viewer for the user to review. The file on disk is NOT modified until the user explicitly saves it.',
  parameters: {
    type: Type.OBJECT,
    properties: {
      path: {
        type: Type.STRING,
        description: 'The path of the file to modify, relative to the workspace root.',
      },
      search_block: {
        type: Type.STRING,
        description: 'The exact block of code to find in the file (multi-line). Must match exactly.',
      },
      replace_block: {
        type: Type.STRING,
        description: 'The replacement code block.',
      },
      description: {
        type: Type.STRING,
        description: 'Optional. Human-readable summary of what this change does.',
      },
    },
    required: ['path', 'search_block', 'replace_block'],
  },
};

export const IDE_WRITE_NEW_FILE_DECLARATION = {
  name: 'ide_write_new_file',
  description: 'Creates a new file with the specified content and opens a diff viewer for the user to review. The file on disk is NOT modified until the user explicitly saves it.',
  parameters: {
    type: Type.OBJECT,
    properties: {
      path: {
        type: Type.STRING,
        description: 'The path of the new file to create, relative to the workspace root.',
      },
      content: {
        type: Type.STRING,
        description: 'The full content of the new file.',
      },
      description: {
        type: Type.STRING,
        description: 'Optional. Human-readable summary of why this file is being created.',
      },
    },
    required: ['path', 'content'],
  },
};

export const IDE_GET_DIAGNOSTICS_DECLARATION = {
  name: 'ide_get_diagnostics',
  description: 'Retrieves diagnostics (errors, warnings) from the IDE\'s Language Server for a specific file, enabling the AI to detect compile errors and type mismatches after applying changes.',
  parameters: {
    type: Type.OBJECT,
    properties: {
      path: {
        type: Type.STRING,
        description: 'The path of the file relative to the workspace root.',
      },
      severity: {
        type: Type.STRING,
        description: 'Optional. Filter by severity: "error", "warning", or "all". Default is "error".',
      },
    },
    required: ['path'],
  },
};

export const IDE_TOOL_DECLARATIONS = [
  IDE_READ_FILE_DECLARATION,
  IDE_LIST_DIRECTORY_DECLARATION,
  IDE_SEARCH_TEXT_DECLARATION,
  IDE_APPLY_DIFF_DECLARATION,
  IDE_WRITE_NEW_FILE_DECLARATION,
  IDE_GET_DIAGNOSTICS_DECLARATION,
];

export const IDE_TOOLS_CONFIG = {
  functionDeclarations: IDE_TOOL_DECLARATIONS,
};
