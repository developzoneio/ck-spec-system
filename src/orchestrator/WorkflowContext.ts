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
  // Bug Workflow states
  RCA_Analysis = 'RCA_Analysis',
  Gate_RCA_Approval = 'Gate_RCA_Approval',
  Failing_Test = 'Failing_Test',
  Gate_Failing_Test_Visual_Diff = 'Gate_Failing_Test_Visual_Diff',
  Fix_Implementation = 'Fix_Implementation',
  Gate_Fix_Visual_Diff = 'Gate_Fix_Visual_Diff',
  // Refactor Workflow states
  Coverage_Check = 'Coverage_Check',
  Gate_Coverage_Fail = 'Gate_Coverage_Fail',
  Refactor_Implement = 'Refactor_Implement',
  // Perf Workflow states
  Baseline_Measurement = 'Baseline_Measurement',
  Gate_Baseline_Approval = 'Gate_Baseline_Approval',
  Perf_Implement = 'Perf_Implement',
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
  // Bug Workflow events
  RCA_GENERATED = 'RCA_GENERATED',
  RCA_APPROVED = 'RCA_APPROVED',
  RCA_REJECTED = 'RCA_REJECTED',
  FAILING_TEST_GENERATED = 'FAILING_TEST_GENERATED',
  FAILING_TEST_APPROVED = 'FAILING_TEST_APPROVED',
  FAILING_TEST_REJECTED = 'FAILING_TEST_REJECTED',
  FIX_GENERATED = 'FIX_GENERATED',
  FIX_APPROVED = 'FIX_APPROVED',
  FIX_REJECTED = 'FIX_REJECTED',
  // Refactor Workflow events
  COVERAGE_CHECK_PASSED = 'COVERAGE_CHECK_PASSED',
  COVERAGE_CHECK_FAILED = 'COVERAGE_CHECK_FAILED',
  // Perf Workflow events
  BASELINE_COLLECTED = 'BASELINE_COLLECTED',
  BASELINE_APPROVED = 'BASELINE_APPROVED',
  BASELINE_REJECTED = 'BASELINE_REJECTED',
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
