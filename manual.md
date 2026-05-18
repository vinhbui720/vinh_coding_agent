# MANUAL - vinh_coding_agent

Tài liệu này tổng hợp **toàn bộ skill** và **feature chính** của repo `vinh_coding_agent`, theo hướng vận hành thực tế trên nhiều máy.

## 1) Mục tiêu của repo

Repo này là bộ dotfiles + wrappers để tái tạo môi trường làm việc Jcode nhanh, ổn định, portable:
- WezTerm config
- Jcode config
- Skill nội bộ
- Tích hợp **Jcode ↔ agentmemory** theo mô hình **wrapper-only**

Nguyên tắc quan trọng:
- Giữ nguyên memory native của Jcode
- Agentmemory chỉ bổ sung (additive), không thay thế
- Không patch trực tiếp upstream core khi không cần thiết

## 2) Cấu trúc chính

- `home/`:
  - Chứa các file/dir sẽ được symlink ra `$HOME`
  - Bao gồm `.jcode`, `.memory-wrapper`, `.local/bin/jcode-wrappers`, `.wezterm.lua`
- `scripts/`:
  - `bootstrap.sh`: setup nhanh máy mới
  - `install.sh`: tạo symlink managed paths
  - `post-install.sh`: hậu cài đặt (PATH, shell init...)
  - `install-external-skills.sh`: cài external skills
  - `validate.sh`: kiểm tra toàn bộ tích hợp
- `docs/`:
  - tài liệu bổ sung (external skills...)

## 3) Các feature hiện tại

### 3.1 Cross-machine bootstrap

Dựng máy mới nhanh:
```bash
cd ~/...
bash scripts/bootstrap.sh
```

Script sẽ:
- kiểm tra dependencies
- tạo symlink live paths
- đảm bảo PATH wrapper đúng thứ tự
- setup memory wrapper env cơ bản
- clone/cài skill ngoài cần thiết
- validate sau cài

### 3.2 Symlink-managed config

Mọi config quan trọng được quản lý qua symlink từ `$HOME` về repo để:
- version control rõ ràng
- rollback dễ
- đồng bộ máy khác an toàn

### 3.3 Wrapper-only agentmemory integration

Thành phần chính ở `~/.memory-wrapper/bin`:
- `agentmemory-start`: start/restart dịch vụ
- `agentmemory-status`: kiểm tra trạng thái
- `memory-search`: tìm memory theo query
- `memory-save`: lưu memory
- `memory-save-and-extract`: lưu + extract vào graph
- `graph-stats`: thống kê graph nodes/edges
- `graph-query`: query quan hệ kiến thức
- `crystallize`: lưu tri thức permanent
- `sync-memory`: đồng bộ memory mesh/peers
- `memory-doctor`: tự chẩn đoán tổng hợp, có `--fix`

### 3.4 Knowledge graph + viewer

- Graph endpoint hoạt động qua agentmemory service
- Có thể xem graph trên UI (thường `http://localhost:3113`, tab Graph)
- Query bằng `graph-query` để khai thác relation khi làm việc/ra quyết định

### 3.5 Safe config sync workflow

Skill `config-sync` giúp đồng bộ git repo theo chính sách an toàn:
- behind -> pull ff
- ahead -> push
- dirty/diverged -> dừng và báo hướng xử lý
- tránh force-push hoặc auto-commit mù

### 3.6 Gog-vinh workspace automation

Skill `gog-vinh` hỗ trợ thao tác Google Workspace theo account alias (personal/work/study):
- inbox, search mail, draft/send
- calendar list/search/create/update/delete
- lịch today/tomorrow/week

## 4) Danh sách skills và cách dùng

## 4.1 Skills cốt lõi cho memory/graph

### `/load-context`
Mục đích:
- nạp nhanh bối cảnh task từ memory + graph + crystals

Khi dùng:
- đầu phiên làm việc
- trước khi tiếp tục task dài nhiều ngày

CLI tương đương:
```bash
~/.memory-wrapper/bin/memory-search "<query>" 7
```

### `/save-decision`
Mục đích:
- lưu quyết định kỹ thuật/lesson
- thường kèm auto graph extract

Khi dùng:
- sau khi fix bug quan trọng
- sau khi chốt architecture/convention

CLI tương đương:
```bash
~/.memory-wrapper/bin/memory-save-and-extract decision "<title>" "<content>"
```

### `/graph-query`
Mục đích:
- truy vấn knowledge graph để xem liên hệ giữa concept/decision/file

CLI tương đương:
```bash
~/.memory-wrapper/bin/graph-query "<query>" 10
```

### `/crystallize`
Mục đích:
- lưu tri thức quan trọng dạng bền vững (permanent)

CLI tương đương:
```bash
~/.memory-wrapper/bin/crystallize "<title>" "<content>" "tag1,tag2"
```

### `/bm25-search`
Mục đích:
- tìm exact keyword khi semantic search không đủ chính xác

### `/sync-memory`
Mục đích:
- sync long-term memory giữa peer machines

## 4.2 Skills vận hành hệ thống

### `/config-sync`
- Đồng bộ repo config nhiều máy qua git với guardrails an toàn

### `/gog-vinh`
- Bộ thao tác Gmail/Calendar cho 3 account alias

### `/notebooklm`
- Query nguồn từ NotebookLM để trả lời có basis tài liệu
- Repo này không vendor source upstream, cài ngoài

## 4.3 Engineering skills (Matt Pocock)

### `/diagnose`
Mục đích:
- Quy trình chẩn đoán bug có kỷ luật: reproduce → minimize → hypothesize → instrument → fix → regression-test

Khi dùng:
- Gặp bug khó, performance regression
- Cần feedback loop nhanh để isolate root cause
- Nói "diagnose this" hoặc "debug this"

Workflow tóm tắt:
1. Build feedback loop (failing test, curl script, headless browser, bisection...)
2. Reproduce bug reliably
3. Generate 3-5 ranked hypotheses (show user trước khi test)
4. Instrument one variable at a time, tag debug logs `[DEBUG-xxxx]`
5. Write regression test → fix → verify
6. Cleanup debug logs, post-mortem

### `/grill-with-docs`
Mục đích:
- Grilling session thách thức plan của bạn dựa trên domain model hiện tại
- Tự động cập nhật `CONTEXT.md` và ADRs khi decision crystallize

Khi dùng:
- Trước khi implement feature mới
- Cần stress-test plan against project's domain language
- Muốn sharpen terminology và challenge assumptions

Workflow:
- Agent phỏng vấn từng câu, cross-reference code và CONTEXT.md
- Challenge term conflicts, propose canonical terms
- Update CONTEXT.md inline khi term được resolve
- Offer ADR chỉ khi: hard to reverse + surprising without context + real trade-off

### `/improve-codebase-architecture`
Mục đích:
- Tìm deepening opportunities: biến shallow modules thành deep modules
- Cải thiện testability và AI-navigability

Khi dùng:
- Muốn refactor để codebase maintainable hơn
- Tìm module shallow (interface gần bằng implementation)
- Consolidate tightly-coupled modules

Key concepts:
- **Depth** = leverage: nhiều behavior ẩn sau interface nhỏ
- **Deletion test**: xóa module → complexity biến mất (pass-through) hay lan ra N callers (earning keep)?
- **Seam**: nơi behavior có thể thay đổi không cần edit in-place

### `/prototype`
Mục đích:
- Build throwaway prototype để flesh out design trước khi commit

Khi dùng:
- Cần sanity-check data model hoặc state machine
- Muốn mock up UI với nhiều variation
- Nói "prototype this" hoặc "let me play with it"

Hai nhánh:
1. **Logic prototype**: runnable terminal app cho state/business-logic questions
2. **UI prototype**: nhiều radically different UI variations toggleable từ một route

### `/setup-matt-pocock-skills`
Mục đích:
- Scaffold per-repo config cho engineering skills: issue tracker, triage labels, domain docs

Khi dùng:
- Lần đầu dùng `/to-issues`, `/triage`, `/diagnose`, `/tdd` trong một repo
- Khi skills thiếu context về issue tracker hoặc triage labels

Output:
- `## Agent skills` block trong CLAUDE.md/AGENTS.md
- `docs/agents/issue-tracker.md`, `triage-labels.md`, `domain.md`

### `/tdd`
Mục đích:
- Test-driven development theo red-green-refactor loop
- Vertical slices (tracer bullets), KHÔNG horizontal slices

Khi dùng:
- Build feature mới bằng TDD
- Fix bug với test-first approach

Workflow:
1. Plan: confirm interface + behaviors to test với user
2. Tracer bullet: ONE test → ONE implementation
3. Incremental loop: RED → GREEN per behavior
4. Refactor (chỉ khi GREEN)

Anti-pattern: KHÔNG viết tất cả test trước rồi implement sau (horizontal slicing)

### `/to-issues`
Mục đích:
- Break plan/spec/PRD thành independently-grabbable issues trên issue tracker
- Dùng vertical slices (tracer bullets), không horizontal slices

Khi dùng:
- Có plan/PRD cần chia thành tickets
- Muốn parallelize work cho nhiều người/agents

Output: issues trên GitHub/GitLab/local markdown với dependency order, blocked-by relationships

### `/to-prd`
Mục đích:
- Biến conversation context hiện tại thành PRD và publish lên issue tracker

Khi dùng:
- Sau grilling session, muốn formalize thành PRD
- Cần document feature spec cho team

Output: GitHub/GitLab issue với Problem Statement, Solution, User Stories, Implementation Decisions, Testing Decisions, Out of Scope

### `/triage`
Mục đích:
- Triage issues qua state machine: needs-triage → needs-info / ready-for-agent / ready-for-human / wontfix

Khi dùng:
- Review incoming bugs/feature requests
- Prepare issues cho AFK agent
- Manage issue workflow

State machine roles:
- `needs-triage`: cần maintainer evaluate
- `needs-info`: chờ reporter
- `ready-for-agent`: fully specified, AFK-ready
- `ready-for-human`: cần human
- `wontfix`: reject

### `/zoom-out`
Mục đích:
- Zoom out lên abstraction layer cao hơn, xem map of relevant modules và callers

Khi dùng:
- Không quen code area đang đọc
- Cần hiểu how a piece fits into the bigger picture

## 4.4 Productivity skills (Matt Pocock)

### `/caveman`
Mục đích:
- Ultra-compressed communication mode, giảm ~75% token usage
- Bỏ filler, articles, pleasantries nhưng giữ full technical accuracy

Khi dùng:
- Muốn tiết kiệm tokens
- Nói "caveman mode", "less tokens", "be brief"

### `/grill-me`
Mục đích:
- Phỏng vấn liên tục về plan/design cho đến khi mọi nhánh decision tree được resolve

Khi dùng:
- Stress-test plan trước khi implement
- Muốn think through edge cases
- Khác `/grill-with-docs`: không cần codebase, dùng cho non-code purposes cũng được

### `/handoff`
Mục đích:
- Nén conversation hiện tại thành handoff document cho agent khác tiếp tục

Khi dùng:
- Chuyển task sang session/agent khác
- Context quá dài, cần fresh start có đủ context

### `/write-a-skill`
Mục đích:
- Tạo skill mới với proper structure, progressive disclosure, bundled resources

Khi dùng:
- Muốn tạo skill mới cho Jcode/Claude Code
- Cần template chuẩn cho SKILL.md + resources

## 4.5 Misc skills (Matt Pocock)

### `/git-guardrails-claude-code`
Mục đích:
- Block dangerous git commands trước khi execute: push, reset --hard, clean, branch -D...

Khi dùng:
- Setup safety hooks cho repo mới
- Muốn ngăn agent làm destructive git operations

### `/setup-pre-commit`
Mục đích:
- Setup Husky pre-commit hooks với lint-staged (Prettier), type checking, tests

Khi dùng:
- Repo mới cần pre-commit hooks
- Muốn auto-format + type-check + test on commit

## 4.6 Document skill

### `/latex-document-skill`
Mục đích:
- Universal LaTeX/PDF skill: resume, report, cover letter, presentation, thesis, poster, exam, cheat sheet, chart, table, diagram...
- 50+ document operations bao gồm merge, encrypt, compress, OCR, form filling

Khi dùng:
- Tạo bất kỳ tài liệu LaTeX/PDF nào
- Convert formats (Markdown/DOCX/HTML ↔ LaTeX)
- OCR scanned PDF

Lưu ý: skill này cài local tại `~/.claude/skills/latex-document`, không managed bởi dotfiles repo

## 4.7 Skills/entry liên quan khác trong repo

- `home/.jcode/skills/agentmemory/` (entry skill tổng quan)
- Một số skill được symlink từ `home/.memory-wrapper/skills/*` vào `~/.jcode/skills/*`

## 5) Workflow khuyến nghị hằng ngày

1. Health check:
```bash
~/.memory-wrapper/bin/memory-doctor
# cần thì:
~/.memory-wrapper/bin/memory-doctor --fix
```

2. Load context trước khi code:
```bash
~/.memory-wrapper/bin/memory-search "<task>" 7
```

3. Trong khi làm, lưu decision ngay:
```bash
~/.memory-wrapper/bin/memory-save-and-extract decision "<title>" "<content>"
```

4. Khi cần reasoning sâu, query graph:
```bash
~/.memory-wrapper/bin/graph-query "<concept>" 10
~/.memory-wrapper/bin/graph-stats
```

5. Chốt knowledge lâu dài:
```bash
~/.memory-wrapper/bin/crystallize "<title>" "<content>" "tags"
```

## 6) Troubleshooting nhanh

- Doctor báo lỗi symlink:
  - chạy lại `bash scripts/install.sh`
- Doctor báo health fail:
  - `~/.memory-wrapper/bin/restart-agentmemory`
  - rồi chạy lại `memory-doctor`
- Graph query trả rỗng:
  - kiểm tra `graph-stats` còn nodes/edges không
  - đổi keyword truy vấn sát hơn với content đã lưu
- TUI wezterm/jcode không đúng wrapper:
  - kiểm tra PATH order để `~/.local/bin/jcode-wrappers` đứng trước `/usr/bin`

## 7) Lưu ý bảo mật và phạm vi commit

Không commit:
- token, OAuth, sessions, cache
- `.memory-wrapper/.env`
- local auth state

Repo tập trung vào:
- wrappers
- config
- docs/operational playbook

## 8) Validation checklist trước khi coi là "ổn"

- `bash scripts/validate.sh` pass
- `~/.memory-wrapper/bin/memory-doctor` pass
- `graph-stats` có nodes/edges
- save + query roundtrip hoạt động
- skills symlink đúng vào `~/.jcode/skills`

---

Nếu cần bản ngắn gọn 1 trang (quick cheatsheet) cho daily use, ưu tiên đọc mục trong `README.md`:
- **Agentmemory quick playbook (cross-machine)**
