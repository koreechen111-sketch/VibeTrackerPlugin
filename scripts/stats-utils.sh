#!/usr/bin/env bash
set -euo pipefail

# VibeTracker 统计计算工具

# 使用 awk 替代 bc 进行浮点计算
_calc() {
    awk "BEGIN {printf \"%.2f\", $1}"
}

# 计算采纳率指标
calculate_adoption_metrics() {
    local ai_lines_generated="$1"
    local ai_lines_preserved="$2"
    local ai_lines_modified="$3"
    local ai_lines_deleted="$4"
    local user_lines_added="$5"

    # 避免除以零
    ai_lines_generated=${ai_lines_generated:-1}

    # 计算各指标（保留两位小数）
    local adoption_rate user_deletion_rate user_modification_rate user_addition_rate ai_generation_ratio

    adoption_rate=$(_calc "($ai_lines_preserved + $ai_lines_modified * 0.5) * 100 / $ai_lines_generated")
    user_deletion_rate=$(_calc "$ai_lines_deleted * 100 / $ai_lines_generated")
    user_modification_rate=$(_calc "$ai_lines_modified * 100 / $ai_lines_generated")

    local total_lines=$((ai_lines_preserved + ai_lines_modified + user_lines_added))
    total_lines=${total_lines:-1}
    ai_generation_ratio=$(_calc "($ai_lines_preserved + $ai_lines_modified * 0.5) * 100 / $total_lines")

    user_addition_rate=$(_calc "$user_lines_added * 100 / $total_lines")

    cat <<EOF
{
  "adoption_rate": $adoption_rate,
  "ai_generation_ratio": $ai_generation_ratio,
  "user_deletion_rate": $user_deletion_rate,
  "user_modification_rate": $user_modification_rate,
  "user_addition_rate": $user_addition_rate
}
EOF
}

# 从 Git 差异中提取指标
analyze_commit() {
    local snapshot_commit="$1"
    local current_commit="${2:-HEAD}"

    # 获取变更文件并格式化为 JSON 数组
    local files_json="[]"
    local first=true
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if [[ "$first" == "true" ]]; then
            files_json="[\"$file\""
            first=false
        else
            files_json="$files_json, \"$file\""
        fi
    done <<< "$(git diff --name-only "$snapshot_commit" "$current_commit" 2>/dev/null || true)"
    files_json="$files_json]"

    # 生成统计结果
    cat <<EOF
{
  "commit_hash": "$current_commit",
  "snapshot_commit": "$snapshot_commit",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "metrics": {},
  "files": $files_json
}
EOF
}

# 按文件统计
file_stats() {
    local snapshot_commit="$1"
    local current_commit="${2:-HEAD}"

    local result="["
    local first=true

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local diff_output
        diff_output=$(git diff "$snapshot_commit" "$current_commit" -- "$file" 2>/dev/null || echo "")

        local ai_added=0
        local ai_deleted=0

        while IFS= read -r line; do
            if [[ "$line" =~ ^\+ ]]; then
                ((ai_added++)) 2>/dev/null || true
            elif [[ "$line" =~ ^- ]]; then
                ((ai_deleted++)) 2>/dev/null || true
            fi
        done <<< "$diff_output"

        if [[ "$first" == "true" ]]; then
            first=false
        else
            result="$result, "
        fi
        result="$result{\"file\": \"$file\", \"ai_lines_added\": $ai_added, \"ai_lines_deleted\": $ai_deleted}"
    done <<< "$(git diff --name-only "$snapshot_commit" "$current_commit" 2>/dev/null || true)"

    result="$result]"
    echo "$result"
}