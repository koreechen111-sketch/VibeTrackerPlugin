#!/usr/bin/env bash
set -euo pipefail

# VibeTracker 差异计算工具

# 计算两个提交之间的差异行数统计
diff_stats() {
    local old_commit="$1"
    local new_commit="$2"

    if [[ -z "$old_commit" ]]; then
        old_commit=$(git rev-parse HEAD~1 2>/dev/null) || echo ""
    fi

    if [[ -z "$old_commit" || "$old_commit" == "$new_commit" ]]; then
        echo '{"added":0,"deleted":0,"modified":0}'
        return
    fi

    # 获取差异统计
    local diff_output
    diff_output=$(git diff --no-color "$old_commit..$new_commit" -- .)

    local added=0
    local deleted=0

    # 统计添加和删除的行数
    while IFS= read -r line; do
        if [[ "$line" =~ ^\+ ]]; then
            ((added++)) 2>/dev/null || true
        elif [[ "$line" =~ ^- ]]; then
            ((deleted++)) 2>/dev/null || true
        fi
    done <<< "$diff_output"

    echo "{\"added\":$added,\"deleted\":$deleted}"
}

# 获取文件中被修改的行号
get_modified_lines() {
    local old_commit="$1"
    local new_commit="$2"
    local file_path="$3"

    git diff -U0 "$old_commit" "$new_commit" -- "$file_path" 2>/dev/null | \
        grep -E '^@@' | \
        sed 's/@@.*@@//' || true
}

# 计算两个提交之间的文件差异
file_diff() {
    local old_commit="$1"
    local new_commit="$2"
    local file_path="$3"

    if [[ -z "$old_commit" || "$old_commit" == "$new_commit" ]]; then
        echo ""
        return
    fi

    git diff "$old_commit" "$new_commit" -- "$file_path" 2>/dev/null || echo ""
}

# 获取变更的文件列表
get_changed_files() {
    local old_commit="$1"
    local new_commit="$2"

    if [[ -z "$old_commit" || "$old_commit" == "$new_commit" ]]; then
        echo "[]"
        return
    fi

    local files
    files=$(git diff --name-only "$old_commit" "$new_commit" 2>/dev/null)
    local json="["
    local first=true
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$first" == true ]]; then
            first=false
        else
            json+=","
        fi
        json+="\"$line\""
    done <<< "$files"
    json+="]"
    echo "$json"
}