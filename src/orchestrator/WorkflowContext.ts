export enum WorkflowState {
  Init = 'Init',
  Drafting = 'Drafting',
  Pending_Approval = 'Pending_Approval',
  Done = 'Done',
  // Feature Workflow states
  Spec = 'Spec',
  Gate1_Spec_Approval = 'Gate1_Spec_Approval',
  Plan = 'Plan',
  Gate2_Plan_Approval = 'Gate2_Plan_Approval',
  Implement_Loop = 'Implement_Loop',
  Gate3_Visual_Diff = 'Gate3_Visual_Diff',
  Review = 'Review',
}

export enum WorkflowEvent {
  START = 'START',
  DRAFT_COMPLETE = 'DRAFT_COMPLETE',
  USER_APPROVED = 'USER_APPROVED',
  USER_REJECTED = 'USER_REJECTED',
  COMPLETE = 'COMPLETE',
  // Feature Workflow events
  SPEC_GENERATED = 'SPEC_GENERATED',
  SPEC_APPROVED = 'SPEC_APPROVED',
  SPEC_REJECTED = 'SPEC_REJECTED',
  PLAN_GENERATED = 'PLAN_GENERATED',
  PLAN_APPROVED = 'PLAN_APPROVED',
  PLAN_REJECTED = 'PLAN_REJECTED',
  IMPLEMENT_TASK_COMPLETE = 'IMPLEMENT_TASK_COMPLETE',
  TASK_APPROVED = 'TASK_APPROVED',
  TASK_REJECTED = 'TASK_REJECTED',
  ALL_TASKS_COMPLETE = 'ALL_TASKS_COMPLETE',
  REVIEW_COMPLETE = 'REVIEW_COMPLETE',
}

export interface WorkflowContext {
  workflowId: string;
  ticketId?: string;
  filePaths: string[];
  approvalStatus: 'none' | 'pending' | 'approved' | 'rejected';
  rejectionReason?: string;
  metadata?: Record<string, any>;
  
  // Feature Workflow specific context
  tasks?: any[];
  currentTaskIndex?: number;
  agentContext?: Record<string, any>;
}
