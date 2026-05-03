#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/stats-utils.sh"

# 测试采纳率计算
test_calculate_adoption_metrics() {
    # SDD 中的示例：AI 生成了 100 行，用户保留了 60，修改了 20，删除了 20，添加了 30
    local result
    result=$(calculate_adoption_metrics 100 60 20 20 30)

    local adoption_rate
    adoption_rate=$(echo "$result" | grep -o '"adoption_rate": [0-9.]*' | grep -o '[0-9.]*$')

    # 期望: (60 + 20*0.5) / 100 * 100 = 70
    local expected=70
    local tolerance=0.5
    local diff
    diff=$(awk "BEGIN {print ($adoption_rate - $expected) * ($adoption_rate > $expected ? 1 : -1)}")

    if awk "BEGIN {exit !($diff > $tolerance)}"; then
        echo "FAIL: expected adoption_rate ~70, got $adoption_rate"
        return 1
    fi
    echo "PASS: adoption_rate calculation (expected ~70, got $adoption_rate)"

    # 测试 user_deletion_rate
    local deletion_rate
    deletion_rate=$(echo "$result" | grep -o '"user_deletion_rate": [0-9.]*' | grep -o '[0-9.]*$')
    if awk "BEGIN {exit !($deletion_rate != 20)}"; then
        echo "FAIL: expected deletion_rate 20, got $deletion_rate"
        return 1
    fi
    echo "PASS: user_deletion_rate = 20"

    echo "All stats-utils tests passed!"
}

test_calculate_adoption_metrics