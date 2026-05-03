#!/usr/bin/env bash
set -euo pipefail

# VibeTracker Git 工具函数
SNAPSHOT_BRANCH="vibetracker/ai-snapshots"

# 检查 Git 仓库状态
check_git_repo() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: Not inside a Git repository" >&2
        return 1
    fi
}

# 获取当前分支
get_current_branch() {
    git branch --show-current
}

# 检查快照分支是否存在
snapshot_branch_exists() {
    git rev-parse --verify "$SNAPSHOT_BRANCH" >/dev/null 2>&1
}

# 创建快照分支
create_snapshot_branch() {
    if ! snapshot_branch_exists; then
        git checkout --orphan "$SNAPSHOT_BRANCH"
        git reset --soft
        mkdir -p .vibetracker
        echo '{"snapshots":[]}' > .vibetracker/snapshots.json
        git add .vibetracker/snapshots.json
        git commit -m "Initial vibetracker snapshot branch"
        git checkout "$(get_current_branch)"
    fi
}

# 获取最新的快照提交
get_latest_snapshot() {
    git rev-parse "$SNAPSHOT_BRANCH" 2>/dev/null || echo ""
}

# 在快照分支创建提交
create_snapshot_commit() {
    local session_id="$1"
    local timestamp="$2"
    local summary="$3"
    local files_changed="$4"
    local lines_added="$5"
    local lines_deleted="$6"

    local current_branch
    current_branch=$(get_current_branch)

    git checkout "$SNAPSHOT_BRANCH" 2>/dev/null || {
        create_snapshot_branch
        git checkout "$SNAPSHOT_BRANCH"
    }

    # 创建元数据
    local metadata
    metadata=$(cat <<EOF
{
  "session_id": "$session_id",
  "timestamp": "$timestamp",
  "files_changed": $files_changed,
  "lines_added": $lines_added,
  "lines_deleted": $lines_deleted,
  "summary": "$summary"
}
EOF
)

    # 追加到快照列表
    local snapshots_file=".vibetracker/snapshots.json"
    mkdir -p ".vibetracker"

    if [[ -f "$snapshots_file" ]]; then
        local temp_file
        temp_file=$(mktemp)
        jq --argjson meta "$metadata" '.snapshots += [$meta]' "$snapshots_file" > "$temp_file"
        mv "$temp_file" "$snapshots_file"
    else
        echo '{"snapshots":[]}' > "$snapshots_file"
        local temp_file
        temp_file=$(mktemp)
        jq --argjson meta "$metadata" '.snapshots += [$meta]' "$snapshots_file" > "$temp_file"
        mv "$temp_file" "$snapshots_file"
    fi

    git add "$snapshots_file"
    git commit -m "Snapshot: $session_id"

    local snapshot_commit
    snapshot_commit=$(git rev-parse HEAD)

    # 返回主分支
    git checkout "$current_branch" >/dev/null 2>&1

    echo "$snapshot_commit"
}

# 获取提交的统计信息
get_commit_stats() {
    local commit_hash="${1:-HEAD}"
    git diff --stat "$commit_hash^..$commit_hash" 2>/dev/null || git diff --stat "$commit_hash" 2>/dev/null
}