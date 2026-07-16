export enum WorkflowState {
  Init = 'Init',
  Drafting = 'Drafting',
  Pending_Approval = 'Pending_Approval',
  Done = 'Done',
}

export enum WorkflowEvent {
  START = 'START',
  DRAFT_COMPLETE = 'DRAFT_COMPLETE',
  USER_APPROVED = 'USER_APPROVED',
  USER_REJECTED = 'USER_REJECTED',
  COMPLETE = 'COMPLETE',
}

export interface WorkflowContext {
  workflowId: string;
  ticketId?: string;
  filePaths: string[];
  approvalStatus: 'none' | 'pending' | 'approved' | 'rejected';
  rejectionReason?: string;
  metadata?: Record<string, any>;
}
