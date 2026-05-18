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

## 4.3 Skills/entry liên quan khác trong repo

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
