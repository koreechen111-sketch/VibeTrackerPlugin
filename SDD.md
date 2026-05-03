# VibeTracker - 软件设计文档 (SDD)

**文档信息**

| 属性 | 值 |
|------|-----|
| 版本 | 1.0.0 |
| 日期 | 2026-05-03 |
| 状态 | 已实现 |
| 作者 | Koree |

---

## 1. 概述

### 1.1 项目背景

VibeTracker 是一款专为 Claude Code 设计的轻量级插件，用于精确追踪 AI 生成代码在实际开发中的采纳情况。它通过自动捕获 AI 生成的代码快照，并与用户最终提交的代码进行对比，计算出客观的采纳率指标，帮助开发者和团队量化 AI 辅助编程的实际价值。

### 1.2 目标

- 精确测量 AI 生成代码的采纳率和修改程度
- 提供可量化的 AI 辅助编程效率数据
- 不干扰正常开发流程，保持零侵入性
- 支持本地离线运行，无需外部服务依赖

### 1.3 范围

- 支持 Claude Code 桌面版
- 仅追踪通过 Claude Code 生成的代码变更
- 基于 Git 版本控制系统工作
- 提供本地数据存储和命令行展示

### 1.4 非目标

- 不追踪其他 AI 工具（如 GitHub Copilot）生成的代码
- 不提供云端数据同步或团队协作功能
- 不进行代码质量评估或安全扫描
- 不修改用户的主分支或工作目录

---

## 2. 系统架构

### 2.1 整体架构

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Claude Code   │     │   VibeTracker   │     │   Git 仓库      │
│     插件宿主     │────▶│     插件核心     │────▶│                 │
│                 │     │                 │     │ - 主分支        │
└─────────────────┘     └─────────────────┘     │ - vibetracker/  │
                                                │   ai-snapshots   │
                                                └─────────────────┘
                                                       ▲
                                                       │
┌─────────────────┐     ┌─────────────────┐           │
│     用户界面    │◀────│   指标计算引擎   │───────────┘
│   (CLI 命令行)  │     │                 │
└─────────────────┘     └─────────────────┘
```

### 2.2 组件说明

| 组件 | 文件路径 | 职责 |
|------|----------|------|
| Claude Code 钩子层 | `hooks/session-end.sh` | 监听 SessionEnd 事件，捕获 AI 生成的代码 |
| Git 钩子层 | `hooks/post-commit.sh` | 监听 post-commit 事件，计算采纳率 |
| Git 工具 | `scripts/git-utils.sh` | 管理快照分支和快照提交 |
| 差异工具 | `scripts/diff-utils.sh` | 计算提交间的代码差异 |
| 统计工具 | `scripts/stats-utils.sh` | 计算采纳率指标 |
| CLI 工具 | `cli/vibetracker.sh` | 提供用户交互界面 |

### 2.3 目录结构

```
vibetracker/
├── .claude-plugin/
│   ├── marketplace.json     # 插件市场注册信息
│   └── plugin.json          # 插件配置
├── hooks/
│   ├── session-end.sh       # SessionEnd 事件钩子
│   └── post-commit.sh       # post-commit 钩子
├── scripts/
│   ├── git-utils.sh         # Git 工具函数
│   ├── diff-utils.sh        # 差异计算工具
│   └── stats-utils.sh       # 统计计算工具
├── cli/
│   └── vibetracker.sh       # CLI 命令行工具
├── tests/
│   ├── test-git-utils.sh    # Git 工具测试
│   ├── test-diff-utils.sh   # 差异计算测试
│   └── test-stats-utils.sh  # 统计计算测试
├── install.sh               # 安装脚本
├── README.md                # 用户文档
└── CLAUDE.md                # 开发文档
```

---

## 3. 功能特性

### 3.1 核心功能

| 功能 | 描述 | 实现文件 |
|------|------|----------|
| 自动快照捕获 | 在每次 Claude Code 会话结束后自动记录 AI 生成的代码变更 | `hooks/session-end.sh` |
| 智能差异对比 | 使用 Git 内置的差异算法，精确计算 AI 代码与最终提交代码的相似度 | `scripts/diff-utils.sh` |
| 多维度指标计算 | 提供代码采纳率、删除率、添加率等关键指标 | `scripts/stats-utils.sh` |
| 隔离式数据存储 | 使用独立的 Git 分支存储所有快照数据，完全不影响主分支历史 | `scripts/git-utils.sh` |
| 实时指标展示 | 在 CLI 中显示采纳率数据 | `cli/vibetracker.sh` |

### 3.2 CLI 命令

| 命令 | 描述 |
|------|------|
| `vibetracker stats` | 显示采纳率统计摘要 |
| `vibetracker report` | 生成详细采纳率报告 |
| `vibetracker export` | 导出 CSV 格式数据 |
| `vibetracker history` | 查看采纳率历史趋势 |
| `vibetracker help` | 显示帮助信息 |

### 3.3 增强功能

- 按文件统计: 查看每个文件的 AI 代码采纳情况 (`scripts/stats-utils.sh::file_stats`)
- 时间趋势分析: 展示采纳率随时间的变化趋势 (`cli/vibetracker.sh::cmd_history`)
- 会话级详情: 查看每次 Claude 会话的具体采纳情况 (`.vibetracker/snapshots.json`)
- 导出功能: 将统计数据导出为 CSV 格式 (`cli/vibetracker.sh::cmd_export`)

---

## 4. 接口规范

### 4.1 钩子接口

#### session-end.sh

**触发时机**: 每次 Claude Code 完成代码生成后

**输入**: 无命令行参数，读取工作目录 Git 状态

**输出**:
- 创建快照提交到 `vibetracker/ai-snapshots` 分支
- 保存快照引用到 `.vibetracker/last_snapshot`
- 输出日志: `VibeTracker: Created snapshot <commit_hash>`

**退出码**: 0 成功, 1 失败（非 Git 仓库时静默退出返回 0）

#### post-commit.sh

**触发时机**: 用户执行 `git commit` 成功后

**输入**: 无命令行参数，读取 `.vibetracker/last_snapshot`

**输出**:
- 更新 `.vibetracker/stats.json`
- 输出采纳率: `VibeTracker: 代码采纳率: XX%`

**退出码**: 0 成功

### 4.2 Git 工具函数 (git-utils.sh)

```bash
# 检查是否在 Git 仓库中
check_git_repo() -> 0=是, 1=否

# 获取当前分支名
get_current_branch() -> string

# 检查快照分支是否存在
snapshot_branch_exists() -> 0=存在, 1=不存在

# 创建快照分支
create_snapshot_branch() -> void

# 获取最新的快照提交哈希
get_latest_snapshot() -> string

# 创建快照提交
# 参数: session_id, timestamp, summary, files_changed(json), lines_added, lines_deleted
# 返回: 快照提交哈希
create_snapshot_commit() -> string

# 获取提交的统计信息
get_commit_stats([commit_hash]) -> string
```

### 4.3 差异工具函数 (diff-utils.sh)

```bash
# 计算两个提交之间的差异行数统计
# 参数: old_commit, new_commit
# 返回: {"added": N, "deleted": M, "modified": K}
diff_stats(old_commit, new_commit) -> json

# 获取文件中被修改的行号范围
get_modified_lines(old_commit, new_commit, file_path) -> string

# 计算两个提交之间的文件差异
file_diff(old_commit, new_commit, file_path) -> string

# 获取变更的文件列表
get_changed_files(old_commit, new_commit) -> json_array
```

### 4.4 统计工具函数 (stats-utils.sh)

```bash
# 计算采纳率指标
# 参数: ai_lines_generated, ai_lines_preserved, ai_lines_modified, ai_lines_deleted, user_lines_added
# 返回: {adoption_rate, ai_generation_ratio, user_deletion_rate, user_modification_rate, user_addition_rate}
calculate_adoption_metrics(...) -> json

# 从 Git 差异中提取指标
analyze_commit(snapshot_commit, [current_commit]) -> json

# 按文件统计
file_stats(snapshot_commit, [current_commit]) -> json_array
```

---

## 5. 数据模型

### 5.1 快照元数据

**存储位置**: `vibetracker/ai-snapshots` 分支的 `.vibetracker/snapshots.json`

**结构**:
```json
{
  "snapshots": [
    {
      "session_id": "uuid-string",
      "timestamp": "2026-05-03T10:30:00Z",
      "files_changed": ["src/main.py", "tests/test_main.py"],
      "lines_added": 100,
      "lines_deleted": 20,
      "summary": "Session changes: src/main.py test.py"
    }
  ]
}
```

### 5.2 统计数据

**存储位置**: `.vibetracker/stats.json`

**结构**:
```json
[
  {
    "commit_hash": "abc123def456",
    "snapshot_commit": "def789ghi012",
    "timestamp": "2026-05-03T10:35:00Z",
    "metrics": {
      "adoption_rate": 70.00,
      "ai_generation_ratio": 63.64,
      "user_deletion_rate": 20.00,
      "user_modification_rate": 0.00,
      "user_addition_rate": 27.27
    }
  }
]
```

### 5.3 快照引用

**存储位置**: `.vibetracker/last_snapshot`

**内容**: 最近一次快照提交的哈希值

---

## 6. 指标计算

### 6.1 指标定义

| 指标 | 计算公式 | 描述 |
|------|----------|------|
| 代码采纳率 | `(保留行数 + 修改行数 × 0.5) / AI生成总行数 × 100%` | AI 代码中被最终采纳的比例 |
| AI 生成比率 | `(保留行数 + 修改行数 × 0.5) / 提交总行数 × 100%` | 最终提交中来自 AI 的代码占比 |
| 用户删除率 | `删除行数 / AI生成总行数 × 100%` | AI 代码被用户删除的比例 |
| 用户修改率 | `修改行数 / AI生成总行数 × 100%` | AI 代码被用户修改的比例 |
| 用户添加率 | `用户新增行数 / 提交总行数 × 100%` | 用户在 AI 基础上添加的代码比例 |

### 6.2 计算示例

假设 AI 生成了 100 行代码，用户最终提交时：
- 保留了 60 行完全不变
- 修改了 20 行（部分保留）
- 删除了 20 行
- 新增了 30 行

```
代码采纳率 = (60 + 20×0.5) / 100 × 100% = 70.00%
AI 生成比率 = (60 + 20×0.5) / (60+20+30) × 100% ≈ 63.64%
用户删除率 = 20 / 100 × 100% = 20.00%
用户修改率 = 20 / 100 × 100% = 20.00%
用户添加率 = 30 / 110 × 100% ≈ 27.27%
```

---

## 7. 工作原理

### 7.1 事件钩子机制

#### session-end 钩子流程

```
1. 检查是否在 Git 仓库中
   └─ 否 → 静默退出
2. 检查是否有未提交的变更
   └─ 无 → 输出 "No changes to track" 并退出
3. 生成会话 ID (uuidgen 或时间戳)
4. 获取变更文件列表和行数统计
5. 在 vibetracker/ai-snapshots 分支创建快照提交
6. 保存快照哈希到 .vibetracker/last_snapshot
7. 切换回原分支
```

#### post-commit 钩子流程

```
1. 检查是否在 Git 仓库中
   └─ 否 → 静默退出
2. 检查 .vibetracker/last_snapshot 是否存在
   └─ 否 → 静默退出
3. 获取快照提交和当前 HEAD 提交哈希
4. 计算两个提交之间的差异
5. 统计添加行数和删除行数
6. 调用 calculate_adoption_metrics 计算指标
7. 更新 .vibetracker/stats.json
8. 输出采纳率到控制台
```

### 7.2 快照存储策略

```
用户分支: A --- B --- C (当前 HEAD)
                          \
快照分支:                   S1 (AI 生成代码快照)
                              \
                               S2 (下一次 AI 生成)
```

- 每个 AI 会话对应快照分支上的一个独立提交
- 快照提交包含会话元数据，不包含实际代码
- 快照分支永远不会合并到主分支
- 使用 orphan 分支实现完全隔离

---

## 8. 技术实现

### 8.1 技术栈

| 组件 | 技术 | 版本要求 |
|------|------|----------|
| 核心语言 | Bash | 4.0+ |
| 版本控制 | Git | 2.30+ |
| JSON 处理 | jq | 1.5+ |
| 浮点计算 | awk | - |
| 插件宿主 | Claude Code | - |

### 8.2 依赖管理

**必需依赖**:
- `git` - Git 版本控制系统
- `jq` - JSON 命令行处理器

**可选依赖**:
- `uuidgen` - UUID 生成工具（如果不可用则使用时间戳）

### 8.3 错误处理

所有脚本使用 `set -euo pipefail` 启用严格模式：
- `-e`: 任何命令失败立即退出
- `-u`: 使用未定义变量时报错
- `-pipefail`: 管道中任何命令失败则整个管道失败

### 8.4 兼容性

- 支持 Linux、macOS、Windows (Git Bash/WSL)
- 脚本使用 POSIX 兼容语法
- 文件结束符统一使用 LF

---

## 9. 安装与配置

### 9.1 安装步骤

```bash
# 1. 克隆或链接插件
ln -s /path/to/vibetracker ~/.claude/plugins/vibetracker

# 2. 在项目目录运行安装脚本
cd your-project
bash ~/.claude/plugins/vibetracker/install.sh
```

### 9.2 安装脚本功能

1. 检查 Git 和 jq 依赖
2. 创建 `.vibetracker` 目录
3. 初始化 `vibetracker/ai-snapshots` orphan 分支
4. 创建初始 `snapshots.json` 文件

### 9.3 插件注册

插件通过 `.claude-plugin/plugin.json` 注册：

```json
{
  "name": "vibetracker",
  "version": "1.0.0",
  "hooks": {
    "session.end": "hooks/session-end.sh",
    "post-commit": "hooks/post-commit.sh"
  },
  "commands": {
    "vibetracker": "cli/vibetracker.sh"
  },
  "dependencies": {
    "required": ["git", "jq"],
    "optional": []
  }
}
```

---

## 10. 测试

### 10.1 测试覆盖

| 测试文件 | 覆盖功能 |
|----------|----------|
| `test-git-utils.sh` | Git 仓库检测、分支操作、快照创建 |
| `test-diff-utils.sh` | 差异计算、文件变更检测 |
| `test-stats-utils.sh` | 采纳率指标计算 |

### 10.2 运行测试

```bash
# 运行所有测试
bash vibetracker/tests/test-git-utils.sh
bash vibetracker/tests/test-diff-utils.sh
bash vibetracker/tests/test-stats-utils.sh
```

### 10.3 测试示例

```bash
# 创建临时测试仓库
$ test_git_repo
Initialized empty Git repository in /tmp/tmp.xxxxx/.git/
PASS: check_git_repo
PASS: get_current_branch
PASS: snapshot_branch_exists returns false initially
Switched to a new branch 'vibetracker/ai-snapshots'
PASS: create_snapshot_branch
PASS: get_latest_snapshot
All git-utils tests passed!
```

---

## 11. 使用示例

### 11.1 基本工作流

```bash
# 1. 安装插件
$ bash install.sh
VibeTracker 安装程序
====================
检查依赖...
依赖检查完成
初始化快照分支...
✓ VibeTracker 安装成功!

# 2. 使用 Claude Code 生成代码
# (SessionEnd 钩子自动创建快照)

# 3. 提交代码
$ git add . && git commit -m "feat: 添加新功能"
VibeTracker: 代码采纳率: 75.00%

# 4. 查看统计
$ vibetracker stats
VibeTracker 采纳率统计
================================
总提交数: 1
平均采纳率: 75.00%

最近统计:
  abc123d - 采纳率: 75.00%

# 5. 生成详细报告
$ vibetracker report
VibeTracker 详细报告
================================
提交: abc123d
时间: 2026-05-03T10:35:00Z
采纳率: 75.00%
AI生成比例: 60.00%
删除率: 10.00%
修改率: 15.00%
添加率: 40.00%
---

# 6. 导出数据
$ vibetracker export -o stats.csv
已导出到 stats.csv
```

### 11.2 CSV 导出格式

```csv
commit_hash,timestamp,adoption_rate,ai_generation_ratio,user_deletion_rate,user_modification_rate,user_addition_rate
abc123def456,2026-05-03T10:35:00Z,70.00,63.64,20.00,0.00,27.27
```

---

## 12. 常见问题

**Q: VibeTracker 会将我的代码发送到云端吗？**

A: 不会。所有数据都存储在本地 Git 仓库中，不会发送到任何外部服务器。

**Q: 快照分支会占用大量空间吗？**

A: 不会。Git 使用增量存储，只会存储变更，不会重复存储完整文件。

**Q: 我可以删除旧的快照吗？**

A: 可以。快照数据存储在 `vibetracker/ai-snapshots` 分支，可以安全地重写该分支。

**Q: VibeTracker 会影响我的正常开发流程吗？**

A: 不会。所有操作都在后台进行，不会阻塞用户的正常操作。

**Q: 如果没有 uuidgen 工具会怎样？**

A: 系统会回退使用时间戳 (`date +%s%N`) 作为会话 ID。

---

## 13. 许可证

MIT 许可证

---

## 附录 A: 文件清单

| 文件路径 | 描述 |
|----------|------|
| `.claude-plugin/marketplace.json` | 插件市场注册信息 |
| `.claude-plugin/plugin.json` | 插件配置 |
| `hooks/session-end.sh` | SessionEnd 钩子 |
| `hooks/post-commit.sh` | Post-Commit 钩子 |
| `scripts/git-utils.sh` | Git 工具函数 |
| `scripts/diff-utils.sh` | 差异计算工具 |
| `scripts/stats-utils.sh` | 统计计算工具 |
| `cli/vibetracker.sh` | CLI 工具 |
| `install.sh` | 安装脚本 |
| `tests/test-*.sh` | 测试文件 |
| `README.md` | 用户文档 |
| `CLAUDE.md` | 开发文档 |
| `.gitignore` | Git 忽略规则 |
| `.gitattributes` | Git 属性配置 |

---

## 附录 B: Git 提交历史

| 提交哈希 | 消息 | 功能 |
|----------|------|------|
| `8328f4e` | feat: 项目基础结构 | 插件配置和 README |
| `20c1357` | chore: 添加 Git 配置 | .gitignore 和 .gitattributes |
| `34fabf1` | feat: 实现 Git 工具函数 | git-utils.sh |
| `693d01` | feat: 实现统计计算工具 | stats-utils.sh |
| `acc266c` | feat: 实现差异计算工具 | diff-utils.sh |
| `7d7c94` | feat: 实现 CLI 命令行工具 | vibetracker.sh |
| `4123a0` | feat: 实现 SessionEnd 钩子 | session-end.sh |
| `f3ce93` | feat: 实现 Post-Commit 钩子 | post-commit.sh |
| `31b3cc` | feat: 添加安装脚本 | install.sh |
| `7e7820` | docs: 完善文档 | README.md 和 CLAUDE.md |
