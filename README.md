# Claude Memory Engine

一套可攜式記憶系統，適用於 [Claude Code](https://claude.ai/code) 與 [Gemini CLI](https://github.com/google-gemini/gemini-cli)。安裝一次，AI 即可跨對話記住你的偏好、反饋與專案脈絡，換機器也能無縫恢復。

## 功能特色

- **跨對話持久記憶** — 每次 session 開始時自動載入你的偏好、過往反饋與專案脈絡
- **自動備份到 GitHub** — 記憶同步到你自己的 private repo
- **換機器自動恢復** — 一行指令安裝，記憶立即回來
- **Experience 系統** — session 結束後自動萃取經驗，下次開始時 AI 主動複習並歸檔
- **15 個 Slash Commands** — 在 Claude Code 或 Gemini CLI 中直接管理記憶
- **同時支援 Claude Code 與 Gemini CLI** — 共用記憶，不重複儲存

## 前置需求

- [Claude Code](https://claude.ai/code) 和 / 或 [Gemini CLI](https://github.com/google-gemini/gemini-cli)
- [Node.js](https://nodejs.org/) v18+
- [git](https://git-scm.com/)
- 一個空白的 private GitHub repository（用於記憶備份）

## 安裝

### 安裝 Claude Code 版本

#### Linux / macOS / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main/install.sh | bash
```

#### Windows（PowerShell）

```powershell
irm https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main/install.ps1 | iex
```

安裝過程會：
1. 確認 Node.js 已安裝
2. 詢問你的 private backup repo URL（必填）
3. 將 hook scripts 與 slash commands 安裝到 `~/.claude/`
4. 在 `~/.claude/settings.json` 設定 hooks（保留既有設定）
5. 若 backup repo 為空 → 推送初始化範本
6. 若 backup repo 已有記憶 → 自動恢復到本機

安裝完成後，**重啟 Claude Code** 以啟用 hooks。

### 加裝 Gemini CLI 支援（選用）

安裝程式會自動偵測環境並選擇安裝模式：

- **共用模式**（已安裝 Claude Code）：直接使用 `~/.claude/` 的 scripts 與資料，Gemini 與 Claude 共用同一份記憶
- **獨立模式**（純 Gemini 環境）：scripts 安裝到 `~/.gemini/scripts/hooks/`，資料存放於 `~/.gemini/`

#### Linux / macOS / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main/install-gemini.sh | bash
```

#### Windows（PowerShell）

```powershell
irm https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main/install-gemini.ps1 | iex
```

安裝完成後，**重啟 Gemini CLI** 以啟用 hooks。

## Slash Commands

所有指令使用 `/memory:` 前綴，可在 Claude Code 或 Gemini CLI 中使用。

| 指令 | 說明 |
|------|------|
| `/memory:save` | 儲存資訊到記憶（偏好、反饋、專案脈絡、外部資源連結） |
| `/memory:reload` | 將所有記憶檔案載入當前對話脈絡 |
| `/memory:backup` | 將記憶推送到 GitHub backup repo |
| `/memory:sync` | 同步記憶到 / 從 GitHub（push 或 pull） |
| `/memory:recover` | 從備份還原特定專案的記憶（換機器時使用） |
| `/memory:reflect` | 回顧近期 session、精煉記憶、整理 Experience（建議每週執行一次） |
| `/memory:diary` | 從當前對話撰寫一篇反思日誌 |
| `/memory:learn` | 手動儲存一個踩坑教訓或心得 |
| `/memory:check` | 快速健康檢查記憶檔案與 hooks 狀態 |
| `/memory:full-check` | 全面稽核整個記憶系統 |
| `/memory:health` | 狀態報告：記憶用量、session 數量、hook 狀態 |
| `/memory:search` | 以關鍵字搜尋所有記憶檔案 |
| `/memory:compact-guide` | 建議何時使用 `/compact` 壓縮對話脈絡 |
| `/memory:tasks` | 查看與管理跨專案任務清單 |
| `/memory:experience` | 查看、搜尋或手動儲存 Experience 檔案 |

## 記憶類型

記憶檔案分為四種類型：

| 類型 | 檔名前綴 | 用途 |
|------|---------|------|
| `user` | `user_*.md` | 你的角色、專業背景、個人偏好 |
| `feedback` | `feedback_*.md` | AI 應該做或避免做的事 |
| `project` | `project_*.md` | 當前工作、目標、進行中的事項 |
| `reference` | `reference_*.md` | 外部資源、文件連結 |

## Experience 系統

Experience 是跨 session 的結構化經驗紀錄，比一般記憶更完整，儲存於 backup repo 中持久保存。

**自動運作流程：**
1. **session 結束時** — `session-end.js` 將本次對話的 summary 寫入 `.pending-experience-review.json`
2. **下次 session 開始時** — `session-start.js` 讀取這份待處理紀錄，注入對話脈絡，指示 AI 自動判斷是否有值得萃取的經驗
3. **AI 自動決策** — 若有值得保留的教訓或模式，AI 使用 `/memory:experience save` 歸檔；若沒有，跳過

**手動操作：**
- `/memory:experience list` — 列出所有 experience
- `/memory:experience show <檔名>` — 載入完整內容（漸進式揭露）
- `/memory:experience save` — 手動儲存當前 session 的經驗

每個 Experience 檔案包含：情境、發生了什麼、根本原因、學到的教訓、如何應用。

## 資料儲存結構

```
~/.claude/                         ← 共用儲存（Claude 與 Gemini 共用）
├── settings.json                  ← Claude Code hooks 設定
├── scripts/hooks/                 ← 共用 hook scripts
│   ├── session-start.js           ← session 開始時載入脈絡
│   ├── session-end.js             ← session 結束時儲存摘要
│   ├── memory-sync.js             ← 偵測記憶變更
│   ├── mid-session-checkpoint.js  ← 中途自動存檔（每 20 則訊息）
│   ├── pre-push-check.js          ← git push 前檢查
│   ├── write-guard.js             ← 寫入保護
│   ├── post-tool-logger.js        ← Gemini CLI 工具使用紀錄
│   └── memory-backup.sh           ← session 後自動 commit 記憶
├── hooks/
│   ├── log-skill-ai.js
│   └── log-skill-user.js
├── commands/memory/               ← Claude Code slash commands（15 個）
├── experiences/                   ← 跨專案 Experience 檔案
│   ├── INDEX.md                   ← Experience 索引（每次 session 載入）
│   ├── _template.md               ← Experience 範本
│   └── *.md                       ← 各個 experience 檔案
├── memory-config.json             ← backup repo URL 設定
└── projects/
    └── <project-hash>/
        └── memory/                ← 專案記憶檔案（共用）
            ├── MEMORY.md          ← 索引（每次 session 載入）
            └── *.md               ← 各類型記憶檔案

~/.gemini/                         ← Gemini CLI 設定
├── settings.json                  ← Gemini hooks（指向 ~/.claude/scripts/ 或自身）
└── commands/memory/               ← Gemini CLI slash commands（15 個）
```

**純 Gemini 獨立安裝時**，`~/.gemini/scripts/hooks/` 下會有完整 scripts，並透過 `.memory-home` 檔案設定資料目錄。

## Backup Repository 結構

記憶備份到你自己的 private GitHub repo，結構如下：

```
your-claude-memory/
├── MEMORY.md
├── project-map.json               ← 專案名稱與本機 hash 的對應表
├── experiences/                   ← 跨專案 Experience 檔案
│   ├── INDEX.md
│   └── *.md
└── projects/
    └── <project-name>/
        ├── MEMORY.md
        └── *.md
```

`project-map.json` 將可讀的專案名稱對應到 Claude 內部 hash，讓記憶在換機器或路徑改變後仍能正確恢復。

## 常見問題排解

**安裝後 hooks 沒有觸發？**
重啟 Claude Code / Gemini CLI，hooks 需要在新 session 才會生效。

**安裝時出現 `node: command not found`？**
前往 https://nodejs.org/ 安裝 Node.js 後重新執行安裝指令。

**session 開始時記憶沒有載入？**
執行 `/memory:check` 診斷。也可查看 `~/.claude/sessions/debug.log` 確認 session-end 是否有錯誤。

**換新機器要怎麼恢復記憶？**
執行安裝指令並填入 backup repo URL，自動恢復大部分記憶。未自動恢復的專案可執行 `/memory:recover`。

## 解除安裝

### 移除 Claude Code 安裝

```bash
curl -fsSL https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main/uninstall.sh | bash
```

```powershell
irm https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main/uninstall.ps1 | iex
```

`~/.claude/projects/` 中的記憶檔案不受影響。

### 只移除 Gemini CLI 支援

#### Linux / macOS / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main/uninstall-gemini.sh | bash
```

#### Windows（PowerShell）

```powershell
irm https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main/uninstall-gemini.ps1 | iex
```

此操作只移除 `~/.gemini/commands/memory/` 與 `~/.gemini/settings.json` 中的 hooks，共用 scripts 與記憶檔案不受影響。
