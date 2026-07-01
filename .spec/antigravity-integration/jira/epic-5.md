# EPIC: [SA-500] Trải nghiệm UI/UX & Hard Gates

**Mô tả Epic:** Đây là giai đoạn chuyển đổi lớn nhất về mặt trải nghiệm người dùng. `specwright` nguyên bản yêu cầu người dùng gõ `(y/n)` trên Terminal để xác nhận các bước. Trong môi trường Antigravity IDE, chúng ta sẽ biến các điểm nghẽn (Hard Gates) này thành các luồng tương tác UI trực quan, mượt mà và an toàn. Giao diện phải tận dụng tối đa các thành phần native của IDE như Split-view, Diff Viewer, Command Palette và hệ thống Linter/Diagnostics.

**Mục tiêu (Goals):**
- Xây dựng giao diện tương tác Command Palette và Chatbox để khởi tạo các luồng (Feature, Bug, Refactor).
- Triển khai "Hard Gate 1": Giao diện phê duyệt file Spec và Plan trực quan.
- Triển khai "Hard Gate 2": Giao diện xem trước và phê duyệt mã nguồn (Visual Diff) trước khi ghi đè vào file gốc.
- Đưa kết quả kiểm duyệt của AI (Reviewer Agent) hiển thị trực tiếp lên trình soạn thảo mã (Editor).

---

## TICKET: [SA-501] Tích hợp Command Palette và Chatbox Interceptor
**Loại:** Story
**Mức độ ưu tiên:** Cao (High)
**Epic Link:** SA-500

### Mô tả (Description)
Cung cấp cổng giao tiếp đầu tiên cho người dùng. Người dùng có thể khởi chạy extension thông qua hộp thoại tìm kiếm lệnh (Command Palette) hoặc gõ trực tiếp cú pháp Slash Command vào thanh chat AI của IDE.

### Các công việc cần làm (Tasks)
1. Đăng ký các lệnh chuẩn vào `package.json` của Extension:
   - `> Specwright: New Feature` (`/sd:feature`)
   - `> Specwright: Fix Bug` (`/sd:bug`)
   - `> Specwright: Refactor` (`/sd:refactor`)
2. Viết parser để bóc tách tham số từ lệnh người dùng (ví dụ: bóc tách `<ticket-id>` hoặc mô tả ngắn từ chuỗi `/sd:feature PROJ-123`).
3. Tạo form nhập liệu động (Input Box / Quick Pick) nếu người dùng gọi lệnh mà chưa cung cấp đủ tham số (như ID hoặc tên tính năng).
4. Kết nối các lệnh này với module Orchestrator (đã làm ở Epic 1) để khởi chạy State Machine tương ứng.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Người dùng có thể gọi lệnh từ Command Palette và Chatbox thành công.
* [ ] Extension bóc tách đúng tham số đầu vào và truyền vào context của `sd-spec-architect`.
* [ ] Hiển thị thông báo (Notification/Toast) khi một tiến trình workflow bắt đầu chạy.

---

## TICKET: [SA-502] Giao diện Hard Gate 1 (Spec & Plan Approval Modal)
**Loại:** Story
**Mức độ ưu tiên:** Cao (High)
**Epic Link:** SA-500

### Mô tả (Description)
Khi Agent `sd-spec-architect` soạn xong bản nháp file `00-spec.md` hoặc `01-plan.md`, workflow phải dừng lại (Pause). Hệ thống cần hiển thị giao diện để người dùng đọc, chỉnh sửa và quyết định có đi tiếp hay không.

### Các công việc cần làm (Tasks)
1. Sử dụng Webview API hoặc Editor API của Antigravity IDE để mở giao diện Split-view (Chia đôi màn hình).
2. Nửa bên trái/dưới hiển thị các nút thao tác nổi bật (Action Panel): **"Approve & Continue"**, **"Reject & Revise"**, **"Cancel"**.
3. Nửa bên phải hiển thị nội dung file Markdown vừa được AI sinh ra, cho phép người dùng sửa text trực tiếp.
4. Lắng nghe sự kiện click: Nếu nhấn "Approve", lưu file và gửi tín hiệu (`Event.emit`) báo cho State Machine chuyển sang phase tiếp theo (Execution). Nếu "Reject", bật prompt nhỏ để user nhập lý do và gửi lại cho Architect Agent.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Giao diện Split-view tự động xuất hiện khi State Machine đạt đến trạng thái `Pending_Approval`.
* [ ] Người dùng có thể chỉnh sửa thủ công file Spec/Plan trên UI trước khi approve.
* [ ] Luồng hệ thống tiếp tục chính xác sang Agent `sd-implementer` khi nhấn "Approve".

---

## TICKET: [SA-503] Giao diện Hard Gate 2 (Visual Diff Review)
**Loại:** Story
**Mức độ ưu tiên:** Cao (High)
**Epic Link:** SA-500

### Mô tả (Description)
Là chốt chặn an toàn cuối cùng. Khi `sd-implementer` sinh ra code mới, tuyệt đối không được ghi thẳng vào ổ đĩa. Cần hiển thị giao diện so sánh (Diff) để lập trình viên con người kiểm tra.

### Các công việc cần làm (Tasks)
1. Lắng nghe output từ hàm `ide_apply_diff` (đã làm ở Epic 3).
2. Gọi API mở trình Diff Viewer mặc định của IDE (so sánh file gốc và chuỗi code mới trên RAM).
3. Thêm một thanh công cụ (Toolbar) đè lên Diff Viewer với 2 hành động:
   - **"Accept Changes"**: Xác nhận ghi đè file gốc và đóng Diff.
   - **"Ask AI to Fix"**: Mở một ô nhập liệu nhỏ cho phép user chỉ ra điểm sai (ví dụ: "Dùng biến khác", "Sai logic vòng lặp") và đẩy ngược lại cho `sd-implementer`.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Diff Viewer mở đúng vị trí các dòng code bị sửa đổi.
* [ ] Chỉ khi người dùng click "Accept", file trên đĩa mới thực sự bị thay đổi, đảm bảo an toàn 100%.
* [ ] Luồng tự sửa lỗi (Self-correction) hoạt động trơn tru khi chọn "Ask AI to Fix".

---

## TICKET: [SA-504] UI hiển thị kết quả của `sd-reviewer` (Linter & Decorations)
**Loại:** Story
**Mức độ ưu tiên:** Trung bình (Medium)
**Epic Link:** SA-500

### Mô tả (Description)
Biến kết quả đánh giá (JSON Array) của `sd-reviewer` Agent thành trải nghiệm giống hệt như các công cụ Linter truyền thống (ESLint, SonarQube) ngay bên trong Editor của người dùng.

### Các công việc cần làm (Tasks)
1. Đọc JSON output từ Reviewer (gồm danh sách lỗi chứa: file, line, severity, comment).
2. Ánh xạ các cấp độ `severity` sang các thẻ Diagnostics của IDE:
   - `BLOCK` -> Lỗi (Error - gạch chân lượn sóng màu Đỏ).
   - `WARN` -> Cảnh báo (Warning - gạch chân lượn sóng màu Vàng).
   - `SUGGEST` -> Thông tin (Info/Hint - gạch chân lượn sóng màu Xanh/Xám).
3. Đẩy danh sách lỗi này vào `DiagnosticsCollection` của IDE để IDE tự động hiển thị trong tab "Problems" và vẽ gạch chân trên file code.
4. (Tuỳ chọn) Tạo tính năng "Quick Fix" để user có thể click vào lỗi và yêu cầu AI tự động sinh ra mã sửa lỗi.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Sau khi chạy lệnh `/sd:review`, các lỗi vi phạm thiết kế/kiến trúc do AI phát hiện được vẽ gạch chân chính xác lên đúng dòng code.
* [ ] Khi di chuột (Hover) lên đoạn code gạch chân, hiển thị được lời nhận xét chi tiết và lý do vi phạm của Agent.