#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/git-utils.sh"

# 创建临时测试仓库
test_git_repo() {
    local test_dir
    test_dir=$(mktemp -d)
    cd "$test_dir"

    git init
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "test content" > test.txt
    git add test.txt
    git commit -m "Initial commit"

    # 测试 check_git_repo
    if ! check_git_repo; then
        echo "FAIL: check_git_repo should pass in git repo"
        return 1
    fi
    echo "PASS: check_git_repo"

    # 测试 get_current_branch
    local branch
    branch=$(get_current_branch)
    if [[ "$branch" != "main" && "$branch" != "master" ]]; then
        echo "FAIL: expected main/master, got $branch"
        return 1
    fi
    echo "PASS: get_current_branch"

    # 测试 snapshot_branch_exists (应该返回 false)
    if snapshot_branch_exists; then
        echo "FAIL: snapshot branch should not exist yet"
        return 1
    fi
    echo "PASS: snapshot_branch_exists returns false initially"

    # 测试 create_snapshot_branch
    create_snapshot_branch
    if ! snapshot_branch_exists; then
        echo "FAIL: snapshot branch should exist after creation"
        return 1
    fi
    echo "PASS: create_snapshot_branch"

    # 测试 get_latest_snapshot
    local snapshot
    snapshot=$(get_latest_snapshot)
    if [[ -z "$snapshot" ]]; then
        echo "FAIL: get_latest_snapshot should return a hash"
        return 1
    fi
    echo "PASS: get_latest_snapshot"

    # 清理
    cd /
    rm -rf "$test_dir"
    echo "All git-utils tests passed!"
}

test_git_repo