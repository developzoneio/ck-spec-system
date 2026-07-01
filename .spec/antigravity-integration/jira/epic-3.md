# EPIC: [SA-300] IDE Native Tools (Function Calling Bindings)

**Mô tả Epic:** Trong `specwright` gốc, các Agents tương tác với code thông qua việc thực thi các lệnh bash (grep, sed, cat...) trên Terminal. Điều này tiềm ẩn rủi ro bảo mật, dễ lỗi trên các hệ điều hành khác nhau (Windows vs macOS) và không cung cấp trải nghiệm trực quan. Epic này nhằm mục đích ánh xạ toàn bộ các thao tác đó thành các **Tools (Function Calling)** trỏ trực tiếp vào API Native của Antigravity IDE. AI sẽ giao tiếp với IDE thay vì giao tiếp với Hệ điều hành.

**Mục tiêu (Goals):**
- Xây dựng bộ công cụ thao tác file cục bộ (Read/Search) an toàn, hiệu suất cao.
- Triển khai cơ chế sửa đổi code thông qua Virtual Documents / Diff Viewer của IDE, đảm bảo người dùng luôn có quyền quyết định cuối cùng trước khi ghi xuống đĩa.
- Cấp cho AI khả năng tự kiểm tra lỗi cú pháp bằng cách giao tiếp với Language Server của IDE.

---

## TICKET: [SA-301] Implement File System Tools (Read & Search) qua IDE API
**Loại:** Story
**Mức độ ưu tiên:** Cao (High)
**Epic Link:** SA-300

### Mô tả (Description)
Thay thế các công cụ đọc file và tìm kiếm bằng Terminal (như `cat`, `grep`, `find`) bằng các API native của IDE. Các Agent (đặc biệt là `sd-explorer` và `sd-debugger`) cần công cụ để đào sâu vào các file cụ thể khi Context Caching không đủ chi tiết hoặc cần tra cứu cấu trúc thư mục thời gian thực.

### Các công việc cần làm (Tasks)
1. Định nghĩa Function Declarations (JSON Schema) cho các tool:
   - `ide_read_file(path: string, startLine?: number, endLine?: number)`
   - `ide_list_directory(path: string)`
   - `ide_search_text(query: string, pattern: string)`
2. Triển khai logic xử lý (Handlers) cho các hàm này bằng cách gọi các API tương ứng của Antigravity IDE (ví dụ: Workspace API, FileSystem API).
3. Đăng ký các tools này vào cấu hình mô hình của Google GenAI SDK.
4. Xử lý các lỗi edge-cases: File quá lớn, file binary, đường dẫn không tồn tại.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Gemini Model có thể quyết định gọi tool `ide_read_file` với tham số chính xác khi được hỏi về nội dung một file.
* [ ] Extension trả về nội dung file chính xác cho Model, giới hạn số dòng (nếu có yêu cầu từ `startLine`/`endLine`) để tiết kiệm token.
* [ ] Việc tìm kiếm file/text không sinh ra bất kỳ tiến trình (process) bash/shell nào dưới nền của hệ điều hành.

---

## TICKET: [SA-302] Implement Code Modification Tools (Diff & Apply)
**Loại:** Story
**Mức độ ưu tiên:** Cao (High)
**Epic Link:** SA-300

### Mô tả (Description)
Đây là công cụ quan trọng nhất dành cho `sd-implementer` Agent. Thay vì dùng script thay thế text trực tiếp lên file trên ổ đĩa (rất dễ hỏng code), AI sẽ đề xuất một bản "Diff". Extension sẽ nhận bản Diff này và mở giao diện So sánh (Diff Viewer) có sẵn của IDE.

### Các công việc cần làm (Tasks)
1. Định nghĩa Tool: `ide_apply_diff(path: string, search_block: string, replace_block: string)` (hoặc định dạng chuẩn Unified Diff).
2. Triển khai logic: Khi nhận được yêu cầu từ AI, Extension không `fs.writeFileSync()` ngay. Thay vào đó, tạo một Virtual Document (file tạm trên RAM).
3. Gọi API của Antigravity IDE để mở panel so sánh giữa file gốc và file tạm (`vscode.commands.executeCommand('vscode.diff', ...)` hoặc API tương đương của Antigravity).
4. (Tùy chọn) Thêm tool `ide_write_new_file(path: string, content: string)` cho các file tạo mới hoàn toàn.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] AI trả về lệnh gọi hàm `ide_apply_diff` với đoạn code cũ và đoạn code mới.
* [ ] IDE tự động hiển thị màn hình Split View / Diff Viewer cho người dùng xem trước những gì AI muốn sửa.
* [ ] File thực tế trên đĩa chỉ thay đổi khi người dùng click vào nút "Accept / Save" trên giao diện của IDE.

---

## TICKET: [SA-303] Implement IDE Diagnostics Tool (Linter/Compiler Feedback)
**Loại:** Story
**Mức độ ưu tiên:** Trung bình (Medium)
**Epic Link:** SA-300

### Mô tả (Description)
Để AI trở nên tự chủ hơn và giảm thiểu code lỗi (syntax error, type error), chúng ta cần cấp cho AI khả năng "nhìn" thấy các lạch chân lượn sóng màu đỏ (Linter Errors) giống như một lập trình viên con người. Công cụ này rất hữu ích cho vòng lặp self-correction (tự sửa lỗi) của `sd-implementer`.

### Các công việc cần làm (Tasks)
1. Định nghĩa Tool: `ide_get_diagnostics(path: string)`.
2. Triển khai logic lấy dữ liệu: Truy cập vào API Diagnostics/Problems Panel của Antigravity IDE để trích xuất danh sách các lỗi (Error, Warning) hiện có trên file chỉ định.
3. Chuyển đổi dữ liệu lỗi thành chuỗi text dễ hiểu cho AI (Ví dụ: `Line 42: Type 'string' is not assignable to type 'number'`).
4. Cấu hình để Implementer Agent có thể gọi hàm này sau khi `ide_apply_diff` hoàn tất để check xem code mình vừa viết có compile được không.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] AI gọi hàm `ide_get_diagnostics` và nhận về danh sách lỗi chuẩn xác từ Language Server (TypeScript, Python, C#, v.v.) đang chạy trong IDE.
* [ ] Nếu có lỗi, AI sử dụng thông tin lỗi để tự động gọi lại `ide_apply_diff` nhằm sửa chữa (tối đa 2 vòng lặp).