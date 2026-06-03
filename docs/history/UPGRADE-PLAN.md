# Upgrade Plan — specwright (Gold Standard)

> **Trạng thái:** Chưa sửa file nào. Roadmap đã lên xong, chờ thực thi.  
> **Ngày lập:** 2026-06-03

---

## Quyết định đã chốt (KHÔNG thay đổi nữa)

| Hạng mục | Giá trị |
|---|---|
| **Prefix vận hành** | `sd` |
| **Tên repo mới** | `specwright` (thay `ck-spec-system`) |
| **Slash commands** | `/sd:feature`, `/sd:bug`, `/sd:refactor`, `/sd:perf`, `/sd:rca`, `/sd:review`, `/sd:explore`, `/sd:spec`, `/sd:setup` |
| **Agent names** | `sd-reviewer`, `sd-implementer`, `sd-code-explorer`, `sd-debugger`, `sd-spec-architect` |
| **Install paths** | `commands/sd/`, `agents/sd/`, `hooks/sd/`, `templates/sd/`, `skills/sd/` |
| **Skill names (Phase 3)** | `sd-severity-taxonomy`, `sd-hypothesis-tree`, `sd-atomic-task-format`, `sd-evidence-citation`, `sd-spec-templates` |
| **Installer variable** | bash `PREFIX="sd"` / ps1 `$Prefix='sd'` |

---

## Phạm vi rebrand (số liệu từ quét repo)

| Loại thay đổi | Số lần | Từ → Đến |
|---|---|---|
| Tên repo | ~50 | `ck-spec-system` → `specwright` |
| Slash refs | ~215 | `/ck:` → `/sd:` |
| Agent names | ~122 | `ck:<role>` → `sd-<role>` |
| Install paths | ~67 | `.../ck/` → `.../sd/` |

---

## Roadmap (6 Phases)

### Phase 0 — Pre-flight verification (không sửa file)
- **0.1** Xác nhận CLI version + `PreToolUse` nhận schema `hookSpecificOutput.permissionDecision` hay legacy `{decision:block}`
- **0.2** Xác nhận Claude Code resolve tên agent thế nào (frontmatter `name: ck:reviewer` vs filename)
- **0.3** Baseline snapshot: dry-run cả 2 installer, validate JSON template

### Phase 1 — Low-risk consistency & config
- **1.1** Chốt canonical enum: `Step type=foundation|behavior|wiring|polish|test`, `Complexity=S|M|L`, `Reversibility=trivial|moderate|hard`
- **1.2** Sửa enum drift trong `commands/feature.md` (~dòng 86-97)
- **1.3** Align `commands/refactor.md`, `bug.md`, `perf.md`, `rca.md`
- **1.4** `templates/project-config.template.json` — thay model ID cố định bằng alias (`sonnet`/`haiku`)

### Phase 2 — Full rebrand `ck → sd` + `ck-spec-system → specwright` (atomic)
- **2.1** Lock `PREFIX=sd`, giới thiệu biến PREFIX vào cả 2 installer, build danh sách edit
- **2.2** Rename 5 agent frontmatter: `name: ck:<role>` → `sd-<role>`, thêm `color`, làm giàu `description`
- **2.3** Update 9 `commands/*.md`: `/ck:` → `/sd:`, `ck:<role>` → `sd-<role>`
- **2.4** Rename install paths trong `install.sh` + `install.ps1` (dùng `PREFIX` var)
- **2.5** Update hook banner text: `ck-spec-system` → `specwright`, `/ck:` → `/sd:` (bash + ps1)
- **2.6** Update `templates/*.template.md`, `project-config.template.json`, `settings.template.json`
- **2.7** Update `README.md`, `docs/*.md`, `CONTRIBUTING.md`, `examples/README.md`, `CHANGELOG.md`
- **2.8** Verify 0 orphaned `ck` refs còn sót (grep/Select-String + installer dry-run)

### Phase 3 — Agent Skills architecture
- **3.1** Chốt skill catalog (5 skills, tất cả dùng prefix `sd-`)
- **3.2** Tạo `skills/<name>/SKILL.md` (thư mục mới ở repo root)
- **3.3** Thêm `skills:` vào frontmatter 5 agent
- **3.4** Trim nội dung đã chuyển vào skill ra khỏi body agent (kết hợp cùng pass Phase 2)
- **3.5** Thêm `skills/sd/` vào plan của cả 2 installer
- **3.6** Cập nhật `commands/setup.md` cho skills

### Phase 4 — Hooks upgrade
- **4.1** `hooks/bash/spec-gate.sh`: `emit_block()` → `hookSpecificOutput.permissionDecision='deny'`
- **4.2** `hooks/powershell/spec-gate.ps1`: mirror 4.1, giữ PURE ASCII
- **4.3** OS-aware settings wiring: `install.sh` phát bash snippet, `install.ps1` phát PS snippet

### Phase 5 — Documentation & polish
- **5.1** `README.md`: thêm Skills section, cập nhật agent table + counts
- **5.2** `docs/architecture.md`: thêm `skills/sd/` layer, section Skills, note hook schema mới
- **5.3** `CHANGELOG.md` + sweep `docs/usage.md`, `docs/walkthrough.md`

### Phase 6 — End-to-end regression
- **6.1** Dry-run cả 2 installer + JSON validation + grep 0 orphaned `ck` refs
- **6.2** Smoke test: `/sd:setup` → `/sd:feature` full flow, xác nhận spec-gate deny/allow

---

## File touch matrix

| File | Phase |
|---|---|
| `templates/project-config.template.json` | 1.4, 2.6 |
| `commands/*.md` (×9) | 1.2, 1.3, 2.3 |
| `agents/*.md` (×5) | 2.2, 3.3, 3.4 |
| `install/install.sh`, `install/install.ps1` | 2.4, 3.5, 4.3 |
| `hooks/bash/*`, `hooks/powershell/*` | 2.5, 4.1, 4.2 |
| `templates/*.template.md`, `settings.template.json` | 2.6, 4.3 |
| `README.md`, `docs/*.md`, `CHANGELOG.md` | 2.7, 5.x |
| `skills/**` *(mới, chưa tồn tại)* | 3.2 |
| `commands/setup.md` | 3.6, 4.3 |

---

## Cách tiếp tục trên thiết bị khác

1. `git pull` để lấy file này.
2. Mở Augment, paste nội dung file này vào đầu session.
3. Nói: *"Tiếp tục upgrade plan trong file UPGRADE-PLAN.md, bắt đầu từ Phase 0."*
