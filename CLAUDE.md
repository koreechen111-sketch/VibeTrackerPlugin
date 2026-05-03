# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在本代码仓库中工作时提供指导。

## 项目概述

VibeTracker 是一款 Claude Code 插件，通过对比 AI 生成的代码快照与用户提交来追踪代码采纳率。它使用独立的 Git orphan 分支（`vibetracker/ai-snapshots`）存储会话快照，不影响主分支历史。

## 常用命令

```bash
# 运行所有测试
bash tests/test-git-utils.sh
bash tests/test-diff-utils.sh
bash tests/test-stats-utils.sh

# 安装（在项目目录运行，创建 .vibetracker 目录和快照分支）
bash install.sh

# CLI 命令
cli/vibetracker.sh stats      # 显示采纳率摘要
cli/vibetracker.sh report     # 详细采纳率报告
cli/vibetracker.sh export     # 导出为 CSV
cli/vibetracker.sh history    # 查看采纳率趋势
```

## 架构

```
hooks/
  session-end.sh   → Claude Code 会话结束时捕获 AI 生成代码快照
  post-commit.sh   → 用户提交时计算采纳率指标

scripts/
  git-utils.sh     → 管理快照分支（创建、提交、检出）
  diff-utils.sh    → 计算提交间的差异统计
  stats-utils.sh   → 计算采纳率指标（采纳率、删除率等）

cli/
  vibetracker.sh   → 用户交互界面，查看统计和导出数据
```

## 核心概念

**快照存储**：快照存储在 `vibetracker/ai-snapshots` orphan 分支。每个快照是一个提交，包含更新后的 `.vibetracker/snapshots.json`。

**指标计算**（`scripts/stats-utils.sh`）：
- `adoption_rate`：`(保留行数 + 修改行数×0.5) / AI生成行数 × 100`
- `ai_generation_ratio`：AI 代码在最终提交中的占比
- `user_deletion_rate`、`user_modification_rate`、`user_addition_rate`：用户修改模式

**数据文件**（在项目根目录创建）：
- `.vibetracker/snapshots.json` — 会话快照历史（在快照分支）
- `.vibetracker/stats.json` — 每次提交的采纳率指标
- `.vibetracker/last_snapshot` — 指向最新快照的引用

## 依赖

必需：`git`、`jq`  
可选：`uuidgen`（不可用时回退到时间戳）

## 错误处理

所有脚本使用 `set -euo pipefail`。当不在 Git 仓库中时，脚本会静默退出（返回 0），以避免打断正常的 Git 操作。
