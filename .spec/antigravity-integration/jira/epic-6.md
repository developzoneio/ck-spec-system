# EPIC: [SA-600] Lắp ráp Workflows (End-to-end Workflows)

**Mô tả Epic:** Đây là giai đoạn "lắp ráp" cuối cùng. Ở các Epic trước, chúng ta đã xây dựng từng mảnh ghép rời rạc: State Machine (Epic 1), Các Subagent (Epic 4), Công cụ IDE (Epic 3), và Giao diện Hard Gates (Epic 5). Trong Epic này, chúng ta sẽ xâu chuỗi tất cả lại để tạo thành các luồng công việc (workflows) hoàn chỉnh, tương đương với 11 slash commands của `specwright` gốc. Mục tiêu là đảm bảo luồng dữ liệu chạy xuyên suốt, mượt mà từ lúc nhận lệnh đến lúc hoàn thành.

**Mục tiêu (Goals):**
- Hoàn thiện luồng `/sd:setup` để khởi tạo không gian làm việc thân thiện thông qua giao diện đồ hoạ.
- Lắp ráp thành công luồng `/sd:feature` đi qua đầy đủ 4 Hard Gates.
- Lắp ráp luồng `/sd:bug` với cơ chế phân tích nguyên nhân gốc rễ (Root Cause Analysis).
- Lắp ráp luồng `/sd:refactor` với điều kiện bắt buộc kiểm tra độ bao phủ test (Test Coverage).

---

## TICKET: [SA-601] Cấu hình luồng `/sd:setup` (Khởi tạo dự án)
**Loại:** Story
**Mức độ ưu tiên:** Cao (High)
**Epic Link:** SA-600

### Mô tả (Description)
Lệnh `/sd:setup` giúp dự án mới làm quen với hệ thống AI. Thay vì chạy script tương tác trên terminal, chúng ta sẽ mở một Webview Form trong IDE để thu thập thông tin dự án (Ngôn ngữ lập trình, Framework, Quy tắc code đặc thù) trước khi sinh ra file `GEMINI_CONSTITUTION.md` và `.specs/`.

### Các công việc cần làm (Tasks)
1. Tạo một UI Form (Webview) hiển thị khi người dùng gọi `/sd:setup`. Form bao gồm:
   - Dropdown chọn Tech Stack (Node.js, Python, .NET, v.v.).
   - Textarea để nhập các quy tắc riêng của team.
2. Gửi dữ liệu form này cho `sd-spec-architect` để nó tổng hợp thành một file `GEMINI_CONSTITUTION.md` phù hợp nhất.
3. Kích hoạt module `SetupScaffolder` (đã làm ở Epic 1) để tạo cấu trúc thư mục.
4. Cập nhật `project-config.json` để lưu lại các thiết lập đường dẫn của workspace.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] UI Form hiển thị đẹp mắt và thu thập đủ dữ liệu.
* [ ] Thư mục `.specs/` và file constitution được sinh ra thành công với nội dung được cá nhân hoá theo tech stack đã chọn.
* [ ] Lệnh chạy Idempotent (không ghi đè hoặc làm hỏng cấu trúc nếu thư mục đã tồn tại, chỉ hỏi update).

---

## TICKET: [SA-602] Chạy luồng `/sd:feature` End-to-End
**Loại:** Story
**Mức độ ưu tiên:** Cao (High)
**Epic Link:** SA-600

### Mô tả (Description)
Đây là quy trình cốt lõi và phức tạp nhất. Phải đảm bảo State Machine điều phối chuẩn xác thứ tự gọi các Agents và các điểm dừng UI (Hard Gates). Luồng chuẩn: `Init -> Spec -> Gate 1 -> Plan -> Gate 2 -> Implement (Loop) -> Gate 3 -> Review -> Done`.

### Các công việc cần làm (Tasks)
1. Cấu hình State Machine cho `FeatureWorkflow`.
2. Kết nối theo thứ tự: 
   - Gọi `sd-spec-architect` để viết `00-spec.md`.
   - Dừng ở Hard Gate 1 (Spec Approval Modal).
   - Gọi lại `sd-spec-architect` để chia nhỏ task thành `01-plan.md`.
   - Dừng ở Hard Gate 2 (Plan Approval Modal).
3. Viết vòng lặp Execution: Với mỗi task trong `01-plan.md`, gọi `sd-implementer` thực thi, gọi `ide_apply_diff`, và dừng ở Hard Gate 3 (Visual Diff) cho task đó.
4. Sau khi tất cả tasks hoàn thành, gọi tự động `sd-reviewer` duyệt qua các thay đổi và hiển thị Linter.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] State Machine luân chuyển đúng thứ tự, không bị skip hay lặp vô hạn.
* [ ] Memory/Context được giữ nguyên suốt quá trình (Agent Implementer biết nó đang code cho Spec nào).
* [ ] Nếu người dùng Reject ở bất kỳ Hard Gate nào, luồng có thể quay lùi lại một bước để AI tự sửa chữa.

---

## TICKET: [SA-603] Chạy luồng `/sd:bug` (Root-cause Analysis & Fix)
**Loại:** Story
**Mức độ ưu tiên:** Cao (High)
**Epic Link:** SA-600

### Mô tả (Description)
Luồng xử lý Bug cần cách tiếp cận khác: Khám phá nguyên nhân gốc rễ trước khi sửa chữa. Yêu cầu phối hợp chặt chẽ giữa `sd-debugger` (suy luận cây giả thuyết) và `sd-implementer`.

### Các công việc cần làm (Tasks)
1. Cấu hình State Machine cho `BugWorkflow`.
2. Luồng: 
   - Khởi tạo thư mục `BUG-xxx/` và file `00-rca.md` (Root Cause Analysis).
   - Gọi `sd-debugger` sử dụng Context Caching để đọc logs/stacktrace và đề xuất nguyên nhân gốc rễ.
   - Dừng ở Hard Gate (RCA Approval).
   - Gọi `sd-implementer` viết *Failing Test* (Test thất bại) trước. Dừng ở Visual Diff Gate.
   - Gọi `sd-implementer` viết mã sửa lỗi (Fix) để test pass. Dừng ở Visual Diff Gate.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] File `00-rca.md` được điền đầy đủ theo chuẩn RCA (5 Whys / Proximate vs Root Cause).
* [ ] Hệ thống bắt buộc AI phải sinh ra Unit Test/Integration test chứng minh lỗi (Failing Test) trước khi thực sự sửa code sản phẩm.

---

## TICKET: [SA-604] Chạy luồng `/sd:refactor` & `/sd:perf`
**Loại:** Story
**Mức độ ưu tiên:** Trung bình (Medium)
**Epic Link:** SA-600

### Mô tả (Description)
Hai luồng này có những Hard Gates đặc thù mang tính hệ thống. Đối với Refactor, `specwright` yêu cầu phải có Test Coverage > 80% mới được chạm vào code. Đối với Perf, phải đo Baseline trước.

### Các công việc cần làm (Tasks)
1. Cấu hình `RefactorWorkflow`. Thêm bước gọi Tool check Coverage (tích hợp với các công cụ như `jest --coverage` hoặc `dotnet test`) thông qua hàm `ide_run_terminal_command` (chỉ cấp quyền chạy lệnh test/read-only).
2. Nếu Coverage < 80%, Orchestrator tự động chặn luồng, thông báo trên UI yêu cầu viết thêm test trước.
3. Cấu hình `PerfWorkflow`. Yêu cầu Agent sinh ra một script/task để lấy Baseline metrics, lưu vào thư mục `04-artifacts/` trước khi tiến hành tối ưu hoá code.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Luồng Refactor sẽ thất bại (Fail fast) và hiển thị thông báo chặn nếu thư mục code định sửa không đạt chuẩn độ phủ test.
* [ ] Cả 2 luồng đều giữ đúng kỷ luật lưu trữ bằng chứng (logs đo lường, kết quả coverage) vào thư mục nội bộ của spec (dưới `.specs/REF-.../`).