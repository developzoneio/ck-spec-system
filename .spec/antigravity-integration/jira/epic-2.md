# EPIC: [SA-200] Tích hợp Gemini API & Context Engineering

**Mô tả Epic:** Epic này tập trung vào việc kết nối Antigravity Extension với sức mạnh cốt lõi của Google GenAI (Gemini 1.5 Pro/Flash). Mục tiêu chính là tối ưu hóa cách chúng ta giao tiếp với mô hình: chuyển đổi các file quy tắc (Skills) dạng Markdown thành định dạng XML tối ưu cho Gemini, ứng dụng Context Caching để nạp toàn bộ codebase vào bộ nhớ với chi phí rẻ nhất, và sử dụng Structured Outputs (JSON Schema) để đảm bảo Agent luôn trả về dữ liệu đúng định dạng.

**Mục tiêu (Goals):**
- Xây dựng thành công `Prompt Compiler` chuyển đổi linh hoạt giữa Markdown và XML System Instructions.
- Tích hợp và quản lý được vòng đời của Gemini Context Caching (tạo, lưu trữ ID, gia hạn TTL).
- Định nghĩa thành công các JSON Schema ép định dạng đầu ra cho các luồng tạo Spec và Plan.

---

## TICKET: [SA-201] Xây dựng Prompt Compiler (Markdown to XML)
**Loại:** Story
**Mức độ ưu tiên:** Cao (High)
**Epic Link:** SA-200

### Mô tả (Description)
Mô hình Gemini tuân thủ cực kỳ tốt các chỉ dẫn hệ thống (System Instructions) khi chúng được phân tách rõ ràng bằng thẻ XML. Thay vì gửi các file `SKILL.md` và `template` dưới dạng text thô, chúng ta cần một module `PromptCompiler` để đọc cấu trúc gốc, bóc tách frontmatter (nếu có), và bao bọc nội dung bằng các thẻ XML tương ứng (ví dụ: `<skill name="sd-hypothesis-tree">...</skill>`).

### Các công việc cần làm (Tasks)
1. Tạo module `src/compiler/prompt-builder.ts`.
2. Viết hàm đọc danh sách các file SKILL cần thiết từ thư mục `src/assets/skills/`.
3. Xử lý gom nhóm nội dung, bao bọc bằng các thẻ XML như `<system_instructions>`, `<skills>`, `<templates>`.
4. Viết unit test để đảm bảo chuỗi string đầu ra không bị lỗi format hoặc thiếu đóng/mở thẻ.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Hàm `buildSystemInstruction(skills: string[], template: string)` trả về một chuỗi string định dạng XML hợp lệ.
* [ ] Có thể dễ dàng thêm hoặc bớt một "Skill" vào prompt context chỉ bằng cách truyền tên skill vào mảng tham số.
* [ ] Vượt qua các Unit tests kiểm tra chuỗi đầu ra.

---

## TICKET: [SA-202] Quản lý Gemini Context Caching cho Workspace
**Loại:** Story
**Mức độ ưu tiên:** Cao (High)
**Epic Link:** SA-200

### Mô tả (Description)
Để `sd-explorer` hoặc `sd-debugger` có thể truy vấn toàn bộ source code mà không phải gọi tool tìm kiếm lặp đi lặp lại tốn thời gian, ta sẽ đẩy toàn bộ files trong Workspace lên Google Gemini Context Caching. Điều này cho phép nạp hàng triệu token với chi phí thấp và tốc độ phản hồi gần như tức thì. Cần xây dựng module quản lý vòng đời của Cache (TTL - Time To Live).

### Các công việc cần làm (Tasks)
1. Cài đặt SDK `@google/genai` vào dự án.
2. Viết module `src/agents/cache-manager.ts`.
3. Implement hàm đệ quy đọc toàn bộ thư mục workspace (bỏ qua `node_modules`, `.git`, v.v. theo file `.gitignore`).
4. Gửi payload lên API `cachedContents.create` của Gemini.
5. Lưu trữ `cacheName` (hoặc Session ID) trong bộ nhớ của IDE extension.
6. Implement logic kiểm tra hết hạn (TTL) và tự động update/tạo cache mới khi người dùng thay đổi file đáng kể (hoặc trước khi chạy một workflow mới).

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] Extension có thể lấy toàn bộ nội dung text của workspace và upload thành công lên Gemini Context Cache.
* [ ] Lưu trữ và sử dụng lại được `cacheName` cho các API call tiếp theo (Generate Content).
* [ ] Nếu Cache hết hạn, hệ thống tự động phát hiện và build lại Cache mới mà không làm crash luồng.

---

## TICKET: [SA-203] Định nghĩa JSON Schema (Structured Output) cho Spec & Plan
**Loại:** Task
**Mức độ ưu tiên:** Trung bình (Medium)
**Epic Link:** SA-200

### Mô tả (Description)
Các file như `00-spec.md` hay `01-plan.md` cần có cấu trúc rất chặt chẽ (Atomic tasks, Impact, Context) để các subagent sau này đọc hiểu. Thay vì yêu cầu LLM "cố gắng xuất ra Markdown đúng chuẩn", ta sẽ dùng tính năng **Structured Outputs** của Gemini (thông qua `responseSchema`). LLM sẽ trả về đối tượng JSON, sau đó code của chúng ta sẽ map JSON đó thành file Markdown hiển thị cho người dùng.

### Các công việc cần làm (Tasks)
1. Định nghĩa TypeScript Interfaces cho `SpecDocument` (chứa Context, Goals, Impact...) và `PlanDocument` (chứa mảng các `AtomicTask`).
2. Định nghĩa cấu trúc `AtomicTask` theo chuẩn specwright (File path, Layer, Complexity, Step type, Code change description).
3. Chuyển đổi các Interfaces này sang định dạng OpenAPI JSON Schema tương thích với tham số `responseSchema` của SDK Google GenAI.
4. Viết hàm parser: Chuyển đổi JSON object nhận được từ API thành file markdown chuẩn theo format của specwright.

### Tiêu chí nghiệm thu (Acceptance Criteria)
* [ ] API call của Agent `sd-spec-architect` được cấu hình với JSON Schema bắt buộc (`responseMimeType: "application/json"`).
* [ ] Đầu ra từ Gemini trả về chính xác 100% định dạng JSON đã định nghĩa, không bị "ảo giác" text rác ở đầu/cuối response.
* [ ] Parser module có thể render thành công file Markdown hiển thị đẹp mắt từ cục JSON nhận được.