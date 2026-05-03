#!/usr/bin/env bash
set -euo pipefail

# VibeTracker Post-Commit 钩子
# 触发时机: 用户执行 git commit 成功后

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/git-utils.sh"
source "$SCRIPT_DIR/../scripts/stats-utils.sh"

# 主函数
main() {
    # 检查是否在 Git 仓库中
    if ! check_git_repo; then
        exit 0
    fi

    # 检查是否有上次快照
    local last_snapshot_file=".vibetracker/last_snapshot"
    if [[ ! -f "$last_snapshot_file" ]]; then
        exit 0
    fi

    local snapshot_commit
    snapshot_commit=$(cat "$last_snapshot_file")

    if [[ -z "$snapshot_commit" ]]; then
        exit 0
    fi

    # 获取当前提交
    local current_commit
    current_commit=$(git rev-parse HEAD)

    # 确保快照提交存在
    if ! git rev-parse --verify "$snapshot_commit" >/dev/null 2>&1; then
        echo "VibeTracker: Snapshot commit not found"
        exit 0
    fi

    # 计算采纳率
    local diff_output
    diff_output=$(git diff "$snapshot_commit" "$current_commit" 2>/dev/null || echo "")

    local ai_added=0
    local ai_deleted=0
    local preserved=0

    while IFS= read -r line; do
        if [[ "$line" =~ ^\+ ]]; then
            ((ai_added++)) 2>/dev/null || true
        elif [[ "$line" =~ ^- ]]; then
            ((ai_deleted++)) 2>/dev/null || true
        fi
    done <<< "$diff_output"

    # 假设保留的行 = AI 添加的 - 被删除的（简化计算）
    preserved=$((ai_added > ai_deleted ? ai_added - ai_deleted : 0))

    # 计算指标
    local metrics
    metrics=$(calculate_adoption_metrics "$ai_added" "$preserved" "0" "$ai_deleted" "0")

    # 生成统计结果
    local stats_json
    stats_json=$(cat <<EOF
{
  "commit_hash": "$current_commit",
  "snapshot_commit": "$snapshot_commit",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "metrics": $metrics
}
EOF
)

    # 保存统计结果
    mkdir -p .vibetracker
    local stats_file=".vibetracker/stats.json"

    if [[ -f "$stats_file" ]]; then
        local temp_file
        temp_file=$(mktemp)
        jq --argjson stat "$stats_json" '. += [$stat]' "$stats_file" > "$temp_file"
        mv "$temp_file" "$stats_file"
    else
        echo "[$stats_json]" > "$stats_file"
    fi

    # 输出采纳率
    local adoption_rate
    adoption_rate=$(echo "$metrics" | jq '.adoption_rate')
    echo "VibeTracker: 代码采纳率: ${adoption_rate}%"
}

main "$@"