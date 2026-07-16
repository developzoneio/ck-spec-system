export interface SetupFormData {
  projectName: string;
  language: string;
  framework: string;
  database?: string;
  teamRules: string;
  shell: 'powershell' | 'bash' | 'both';
}

export type WorkspaceState = 'fresh' | 'partial' | 'complete';

export interface SetupResult {
  success: boolean;
  filesCreated: string[];
  filesSkipped: string[];
  placeholdersRemaining: number;
  constitutionGenerated: boolean;
  message: string;
}
