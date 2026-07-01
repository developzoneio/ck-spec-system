# EPIC: [SA-100] Nền tảng Kiến trúc (Foundation & Setup) cho Specwright-Antigravity

**Mô tả Epic:** Thiết lập bộ khung cơ bản để chuyển đổi dự án `specwright` từ một công cụ CLI thành một Extension hoạt động native trên Antigravity IDE. Epic này bao gồm việc khởi tạo dự án, thiết lập bộ điều phối trạng thái (State Machine) thay thế cho luồng Terminal cũ, và di chuyển/quy hoạch lại cấu trúc thư mục cốt lõi (Skills, Templates).

**Mục tiêu (Goals):**
- Có một repo Extension hoàn chỉnh, build được và load được vào Antigravity IDE ở chế độ Dev.
- Xây dựng thành công class Orchestrator/State Machine lõi để quản lý các Hard Gates.
- Port thành công tài nguyên tĩnh (Markdown prompts) từ specwright gốc.

---

## TICKET: [SA-101] Khởi tạo Project Antigravity Extension
**Loại:** Task
**Mức độ ưu tiên:** Cao (High)
**Epic Link:** SA-100

### Mô tả (Description)
Cần khởi tạo một dự án TypeScript/Node.js tuân thủ đúng chuẩn API Extension của Antigravity IDE. Đây sẽ là nền tảng để chạy toàn bộ các agent và workflow của specwright sau này. Không sử dụng các shell script gốc, mọi tương tác phải thông qua Extension context.

### Các công việc cần làm (Tasks)
1. Khởi tạo `package.json` với các thông tin manifest cần thiết cho Antigravity IDE.
2. Thiết lập TypeScript config (`tsconfig.json`) với target phù hợp cho môi trường Node/Extension.
3. Thiết lập bundler (Webpack hoặc Vite) để đóng gói extension.
4. Cấu hình ESLint và Prettier theo chuẩn dự án.
5. Viết file entry `src/extension.ts` cơ bản, đăng ký một lệnh (command) test.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Dự án có thể chạy lệnh `npm run build` (hoặc yarn/pnpm) mà không có lỗi TypeScript hay Linter.
* [ ] Khi load thư mục build vào Antigravity IDE (Developer Mode), extension kích hoạt thành công.
* [ ] Gõ lệnh `> Specwright: Hello` trong Command Palette của IDE sẽ in ra dòng log "Hello Antigravity" trong console của IDE.

---

## TICKET: [SA-102] Thiết kế State Machine Core (Bộ điều phối trạng thái)
**Loại:** Task
**Mức độ ưu tiên:** Cao (High)
**Epic Link:** SA-100

### Mô tả (Description)
Trong specwright gốc, luồng công việc (spec -> plan -> execute) bị đứt đoạn và phụ thuộc vào Terminal hook. Chúng ta cần một module `Orchestrator` chạy trong bộ nhớ của Extension để quản lý State Machine. Module này phải có khả năng lưu trữ Context (Memory) giữa các bước và hỗ trợ "Pause" (chờ user click Approve trên UI) trước khi chuyển trạng thái.

### Các công việc cần làm (Tasks)
1. Tạo thư mục `src/orchestrator/`.
2. Định nghĩa interface cho `WorkflowContext` (lưu trữ metadata như ticket ID, file paths, approval status).
3. Implement `StateMachine` class (có thể tự viết hoặc tích hợp thư viện nhẹ như `xstate`).
4. Định nghĩa một luồng test đơn giản: `Init` -> `Drafting` -> `Pending_Approval` -> `Done`.
5. Hỗ trợ cơ chế Event Emit/Listen để IDE UI có thể bắt sự kiện khi State thay đổi.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Module `StateMachine` có thể khởi tạo một luồng công việc mới với ID duy nhất.
* [ ] State Machine có thể chuyển đổi chính xác từ trạng thái này sang trạng thái khác dựa trên trigger.
* [ ] State Machine có khả năng tạm dừng ở trạng thái `Pending_Approval` và chờ một trigger (ví dụ: `USER_APPROVED`) để tiếp tục.
* [ ] Context data không bị mất hoặc reset khi chuyển qua lại giữa các trạng thái.

---

## TICKET: [SA-103] Di chuyển và định dạng lại cấu trúc thư mục cốt lõi
**Loại:** Task
**Mức độ ưu tiên:** Trung bình (Medium)
**Epic Link:** SA-100

### Mô tả (Description)
Mang các thành phần "tĩnh" từ repo `developzoneio/specwright` gốc sang kiến trúc mới. Đổi tên và tối ưu hóa lại các file template và quy tắc cốt lõi (Constitution) để phù hợp với ngữ cảnh dùng Gemini.

### Các công việc cần làm (Tasks)
1. Copy toàn bộ thư mục `skills/` và `templates/` từ repo gốc vào `src/assets/` của project mới.
2. Cập nhật nội dung: Đổi các tham chiếu từ "Claude" thành "Gemini", đổi `CLAUDE.md` thành mẫu `GEMINI_CONSTITUTION.md`.
3. Viết một module `SetupScaffolder` (`src/tools/setup-scaffolder.ts`): Có nhiệm vụ tạo thư mục `.specs/` và copy file `GEMINI_CONSTITUTION.md` vào thư mục gốc của workspace người dùng hiện tại (nếu chưa có).

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Tất cả các file trong `skills/` và `templates/` đã được loại bỏ các tham chiếu Hardcode đến Claude/Anthropic.
* [ ] Chạy hàm `SetupScaffolder.initWorkspace()` trong một dự án test sẽ tự động tạo thư mục `.specs/` và file `GEMINI_CONSTITUTION.md` thành công.
* [ ] Nếu thư mục `.specs/` đã tồn tại, hàm sẽ không ghi đè (Idempotent).