#!/usr/bin/env bash
set -euo pipefail

# VibeTracker 安装脚本

echo "VibeTracker 安装程序"
echo "===================="

# 检查依赖
echo "检查依赖..."

if ! command -v git &> /dev/null; then
    echo "错误: 需要安装 Git"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "警告: 未安装 jq，部分功能可能不可用"
fi

echo "依赖检查完成"

# 初始化 vibetracker 目录
mkdir -p .vibetracker

# 创建快照分支
echo "初始化快照分支..."
git checkout --orphan vibetracker/ai-snapshots 2>/dev/null || true
mkdir -p .vibetracker
echo '{"snapshots":[]}' > .vibetracker/snapshots.json
git add .vibetracker/snapshots.json
git commit -m "Initialize vibetracker" 2>/dev/null || true

# 返回原分支
current_branch=$(git branch --show-current)
if [[ -n "$current_branch" ]] && [[ "$current_branch" != "vibetracker/ai-snapshots" ]]; then
    git checkout "$current_branch" 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}VibeTracker 安装成功!${NC}"
echo ""
echo "下一步:"
echo "  1. 将插件链接到 Claude Code: ln -s \$(pwd) ~/.claude/plugins/vibetracker"
echo "  2. 使用 vibetracker stats 查看采纳率"
echo "  3. 查看 vibetracker README 了解更多信息"