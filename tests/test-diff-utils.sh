#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/diff-utils.sh"

# 创建临时测试仓库
test_diff_utils() {
    local test_dir
    test_dir=$(mktemp -d)
    cd "$test_dir"

    git init
    git config user.email "test@test.com"
    git config user.name "Test"

    # 初始提交
    echo "line 1" > test.py
    git add test.py
    git commit -m "Initial commit"
    local commit1
    commit1=$(git rev-parse HEAD)

    # 第二次提交 - 添加内容
    echo "line 2" >> test.py
    git add test.py
    git commit -m "Add line 2"
    local commit2
    commit2=$(git rev-parse HEAD)

    # 测试 get_changed_files
    local files
    files=$(get_changed_files "$commit1" "$commit2")
    if [[ "$files" != *'"test.py"'* ]]; then
        echo "FAIL: expected test.py in changed files"
        return 1
    fi
    echo "PASS: get_changed_files"

    # 测试 diff_stats
    local stats
    stats=$(diff_stats "$commit1" "$commit2")
    if [[ "$stats" =~ \"added\":([0-9]+) ]]; then
        local added_count="${BASH_REMATCH[1]}"
        if [[ "$added_count" -gt 0 ]]; then
            echo "PASS: diff_stats"
        else
            echo "FAIL: expected added lines"
            return 1
        fi
    else
        echo "FAIL: invalid diff_stats output: $stats"
        return 1
    fi

    # 测试相同提交（边界情况）
    local empty_stats
    empty_stats=$(diff_stats "$commit2" "$commit2")
    if [[ "$empty_stats" =~ \"added\":0 ]]; then
        echo "PASS: diff_stats handles same commit"
    else
        echo "FAIL: expected 0 added lines for same commit"
        return 1
    fi

    # 清理
    cd /
    rm -rf "$test_dir"
    echo "All diff-utils tests passed!"
}

test_diff_utils