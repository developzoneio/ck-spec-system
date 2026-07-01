# EPIC: [SA-400] The Agents (Hệ thống Subagent)

**Mô tả Epic:** `specwright` hoạt động dựa trên triết lý "Multi-Agent" (Đa Tác Tử) kết hợp với "Model Tiering" (Phân cấp Mô hình). Mỗi agent có một vai trò chuyên biệt, được cấp phát mô hình LLM mạnh yếu khác nhau và quyền hạn truy cập công cụ (Tools) khác nhau. Epic này tập trung vào việc định nghĩa và cài đặt 5 agent cốt lõi của hệ thống thông qua SDK của Google GenAI, áp dụng các System Instructions (Skills) tương ứng cho từng vai trò.

**Mục tiêu (Goals):**
- Chuyển đổi thành công 5 Agents cấu hình từ repo gốc thành các Object/Class trong Extension (TypeScript).
- Áp dụng mô hình định tuyến (Model Routing) chuẩn: Dùng `gemini-1.5-pro` (hoặc `gemini-2.0-pro-exp`) cho các tác vụ suy luận phức tạp (Architect, Debugger, Reviewer) và `gemini-1.5-flash` (hoặc `gemini-2.0-flash`) cho các tác vụ cần tốc độ (Implementer, Explorer).
- Liên kết chặt chẽ các Agent với các công cụ (Tools) đã phát triển ở EPIC 3.

---

## TICKET: [SA-401] Xây dựng `sd-spec-architect` Agent
**Loại:** Story
**Mức độ ưu tiên:** Cao (High)
**Epic Link:** SA-400

### Mô tả (Description)
Agent `sd-spec-architect` là bộ não của quy trình. Nhiệm vụ của nó là tiếp nhận yêu cầu từ người dùng (hoặc JIRA ticket), phân tích codebase, suy luận tác động và viết ra file Spec (`00-spec.md`) và Plan (`01-plan.md`) hoàn chỉnh. Agent này đòi hỏi khả năng lập luận kiến trúc mạnh mẽ.

### Các công việc cần làm (Tasks)
1. Tạo class/module định nghĩa cấu hình cho `ArchitectAgent`.
2. Định cấu hình để Agent sử dụng mô hình **`gemini-1.5-pro`** (hoặc Pro mới nhất).
3. Tiêm (inject) các file Skills (đã chuyển đổi sang XML ở EPIC 2) vào `system_instruction`:
   - `sd-atomic-task-format`
   - `sd-spec-templates`
   - `sd-pattern-discipline`
4. Cấp quyền Tools (Function Calling): `ide_read_file`, `ide_list_directory`, `ide_search_text` và Atlassian MCP (nếu có).
5. Ép đầu ra của Agent bằng JSON Schema (đã tạo ở EPIC 2) để đảm bảo định dạng file `00-spec.md` chuẩn xác.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Agent có thể tiếp nhận một yêu cầu tính năng lỏng lẻo và trả về một đối tượng JSON chuẩn cấu trúc Spec.
* [ ] Nội dung Spec tuân thủ nghiêm ngặt các quy tắc định nghĩa trong `GEMINI_CONSTITUTION.md` và các Skills.
* [ ] Agent có thể giải quyết các tác vụ "chia nhỏ" (Atomic Task Breakdown) chính xác trong file Plan.

---

## TICKET: [SA-402] Xây dựng `sd-implementer` Agent
**Loại:** Story
**Mức độ ưu tiên:** Cao (High)
**Epic Link:** SA-400

### Mô tả (Description)
Trái ngược với Architect, `sd-implementer` là những "công nhân" cần mẫn. Nó nhận đầu vào là **một và chỉ một** Atomic Task từ file Plan và thực hiện việc viết/sửa code cho task đó. Nó cần tuân thủ Scope khắt khe (không sửa code lan man) và cần hoàn thành nhanh chóng.

### Các công việc cần làm (Tasks)
1. Tạo class/module định nghĩa cấu hình cho `ImplementerAgent`.
2. Định cấu hình để Agent sử dụng mô hình **`gemini-1.5-flash`** (để đảm bảo độ trễ thấp và tiết kiệm token).
3. Tiêm các Skills vào `system_instruction`:
   - `sd-atomic-task-format` (để hiểu đầu vào)
   - `sd-pattern-discipline` (để viết code theo pattern của project)
4. Giới hạn cấp quyền Tools một cách khắt khe: **Chỉ cấp** `ide_apply_diff`, `ide_write_new_file`, và `ide_get_diagnostics`. **Không cấp** quyền Search/Read rộng để ép Agent chỉ tập trung vào task được giao.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Khi nhận được payload của 1 Atomic Task, Agent gọi thành công hàm `ide_apply_diff` với mã nguồn chính xác.
* [ ] Agent không cố gắng tự tìm hiểu hay sửa các file nằm ngoài Scope của Atomic Task.
* [ ] Nếu code sinh ra có lỗi, Agent có thể tự kiểm tra (qua Linter Tool) và gọi `ide_apply_diff` lại.

---

## TICKET: [SA-403] Xây dựng `sd-reviewer` Agent
**Loại:** Story
**Mức độ ưu tiên:** Trung bình (Medium)
**Epic Link:** SA-400

### Mô tả (Description)
Agent `sd-reviewer` đóng vai trò kiểm duyệt độc lập (giống như SonarQube hoặc Human Reviewer). Nó kiểm tra lại mã nguồn mà `sd-implementer` vừa viết, đối chiếu với file Spec và `GEMINI_CONSTITUTION.md` để đánh giá chất lượng.

### Các công việc cần làm (Tasks)
1. Tạo class/module định nghĩa cấu hình cho `ReviewerAgent`.
2. Sử dụng mô hình **`gemini-1.5-pro`** (cần khả năng đọc sâu và suy luận kỹ).
3. Tiêm Skill `sd-severity-taxonomy` vào `system_instruction`.
4. Thiết lập đầu ra bắt buộc dưới dạng JSON Schema chứa mảng các lỗi tìm thấy (mỗi lỗi phải có: `file`, `line`, `severity` (BLOCK/WARN/SUGGEST), và `comment`).
5. (Integration) Gắn output của Agent này vào UI hiển thị Linter của Antigravity IDE (đã mô tả ở Epic 5).

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Agent nhận vào đoạn diff code và trả về danh sách các bình luận có gắn thẻ phân loại rủi ro (Severity) chính xác.
* [ ] Agent phát hiện được các lỗi vi phạm thiết kế (vi phạm quy ước trong Constitution), không chỉ dừng ở lỗi cú pháp.

---

## TICKET: [SA-404] Xây dựng `sd-debugger` & `sd-explorer` Agents
**Loại:** Story
**Mức độ ưu tiên:** Trung bình (Medium)
**Epic Link:** SA-400

### Mô tả (Description)
Hai agent này phục vụ cho các luồng gỡ lỗi (Bug/RCA) và khám phá mã nguồn. Đặc điểm chung của chúng là cần quyền truy cập toàn diện vào Codebase và kỹ năng lập luận cây giả thuyết (Hypothesis Tree).

### Các công việc cần làm (Tasks)
1. **Debugger Agent:**
   - Dùng mô hình **`gemini-1.5-pro`**.
   - Gắn kết chặt chẽ với Session ID của **Context Caching** (Epic 2) để hiểu ngữ cảnh toàn dự án.
   - Tiêm Skill `sd-hypothesis-tree` và `sd-evidence-citation` (bắt buộc trích dẫn file:line).
2. **Explorer Agent:**
   - Dùng mô hình **`gemini-1.5-flash`**.
   - Cung cấp quyền đọc, liệt kê file (`ide_read_file`, `ide_list_directory`). Không cấp quyền ghi.
   - Nhiệm vụ chính: Trả lời nhanh các câu hỏi tra cứu hoặc lập bản đồ tác động cho Architect.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Debugger có thể lập luận và đề xuất nguyên nhân gốc rễ (Root Cause) dựa trên Stacktrace và Context Caching.
* [ ] Explorer có thể trả lời nhanh chóng vị trí các hàm/thư viện trong toàn bộ workspace.