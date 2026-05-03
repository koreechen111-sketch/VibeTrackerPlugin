#!/usr/bin/env bash
set -euo pipefail

# VibeTracker SessionEnd 钩子
# 触发时机: 每次 Claude Code 完成代码生成后

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/git-utils.sh"

# 生成会话 ID
generate_session_id() {
    if command -v uuidgen &> /dev/null; then
        uuidgen
    elif [[ -f /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        date +%s%N
    fi
}

# 主函数
main() {
    # 检查是否在 Git 仓库中
    if ! check_git_repo; then
        exit 0
    fi

    # 获取工作目录状态
    local has_changes
    has_changes=$(git status --porcelain | grep -v "^??" | wc -l)

    if [[ "$has_changes" -eq 0 ]]; then
        echo "No changes to track"
        exit 0
    fi

    # 生成会话 ID 和时间戳
    local session_id
    session_id=$(generate_session_id)
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # 获取变更文件
    local files_changed
    files_changed=$(git status --porcelain | grep -v "^??" | awk '{print $2}' | jq -R -s 'split("\n") | map(select(length > 0))')

    # 获取行数统计
    local lines_added=0
    local lines_deleted=0

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local diff_stat
        diff_stat=$(git diff --stat HEAD -- "$file" 2>/dev/null || echo "0 files changed")

        local added
        added=$(echo "$diff_stat" | grep -oP '\d+(?= insertion)' | head -1 || echo 0)
        local deleted
        deleted=$(echo "$diff_stat" | grep -oP '\d+(?= deletion)' | head -1 || echo 0)

        lines_added=$((lines_added + added))
        lines_deleted=$((lines_deleted + deleted))
    done < <(git status --porcelain | grep -v "^??" | awk '{print $2}')

    # 获取摘要
    local summary
    summary="Session changes: $(git status --porcelain | grep -v "^??" | awk '{print $2}' | tr '\n' ' ')"

    # 创建快照提交
    local snapshot_commit
    snapshot_commit=$(create_snapshot_commit "$session_id" "$timestamp" "$summary" "$files_changed" "$lines_added" "$lines_deleted")

    echo "VibeTracker: Created snapshot $snapshot_commit"

    # 保存当前快照引用到文件（供 post-commit 使用）
    mkdir -p .vibetracker
    echo "$snapshot_commit" > .vibetracker/last_snapshot
}

main "$@"