#!/usr/bin/env bash
set -euo pipefail

# VibeTracker CLI 工具

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/stats-utils.sh"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 显示帮助
show_help() {
    cat <<EOF
VibeTracker - Claude Code 代码采纳率追踪插件

用法: vibetracker <命令> [选项]

命令:
    stats       显示采纳率统计
    report      生成详细报告
    export      导出 CSV 格式数据
    history     查看采纳率历史
    help        显示帮助信息

示例:
    vibetracker stats
    vibetracker report
    vibetracker export -o stats.csv
EOF
}

# 显示采纳率统计
cmd_stats() {
    local stats_file=".vibetracker/stats.json"

    if [[ ! -f "$stats_file" ]]; then
        echo -e "${YELLOW}暂无统计数据${NC}"
        return
    fi

    echo -e "${BLUE}VibeTracker 采纳率统计${NC}"
    echo "================================"

    # 计算平均值
    local avg_adoption
    avg_adoption=$(jq '[.[].metrics.adoption_rate] | add / length' "$stats_file" 2>/dev/null || echo "0")

    local total_commits
    total_commits=$(jq 'length' "$stats_file")

    echo -e "总提交数: ${GREEN}$total_commits${NC}"
    echo -e "平均采纳率: ${GREEN}${avg_adoption}%${NC}"
    echo ""

    # 显示最近 5 条
    echo "最近统计:"
    jq -r '.[-5:] | .[] | "  \(.commit_hash[0:7]) - 采纳率: \(.metrics.adoption_rate)%"' "$stats_file" 2>/dev/null || true
}

# 生成详细报告
cmd_report() {
    local stats_file=".vibetracker/stats.json"

    if [[ ! -f "$stats_file" ]]; then
        echo -e "${YELLOW}暂无统计数据${NC}"
        return
    fi

    echo -e "${BLUE}VibeTracker 详细报告${NC}"
    echo "================================"

    jq -r '.[] | "提交: \(.commit_hash[0:7])\n时间: \(.timestamp)\n采纳率: \(.metrics.adoption_rate)%\nAI生成比例: \(.metrics.ai_generation_ratio)%\n删除率: \(.metrics.user_deletion_rate)%\n修改率: \(.metrics.user_modification_rate)%\n添加率: \(.metrics.user_addition_rate)%\n---"' "$stats_file"
}

# 导出 CSV
cmd_export() {
    local output_file="vibetracker_stats.csv"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    local stats_file=".vibetracker/stats.json"

    if [[ ! -f "$stats_file" ]]; then
        echo -e "${YELLOW}暂无统计数据${NC}"
        return
    fi

    echo "commit_hash,timestamp,adoption_rate,ai_generation_ratio,user_deletion_rate,user_modification_rate,user_addition_rate" > "$output_file"
    jq -r '.[] | "\(.commit_hash),\(.timestamp),\(.metrics.adoption_rate),\(.metrics.ai_generation_ratio),\(.metrics.user_deletion_rate),\(.metrics.user_modification_rate),\(.metrics.user_addition_rate)"' "$stats_file" >> "$output_file"

    echo -e "${GREEN}已导出到 $output_file${NC}"
}

# 查看历史
cmd_history() {
    local stats_file=".vibetracker/stats.json"

    if [[ ! -f "$stats_file" ]]; then
        echo -e "${YELLOW}暂无统计数据${NC}"
        return
    fi

    echo -e "${BLUE}采纳率历史趋势${NC}"
    echo "================================"

    jq -r '.[] | "\(.timestamp[0:10]) | \(.metrics.adoption_rate)%"' "$stats_file" | column -t -s '|'
}

# 主入口
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    local command="$1"
    shift

    case "$command" in
        stats)
            cmd_stats "$@"
            ;;
        report)
            cmd_report "$@"
            ;;
        export)
            cmd_export "$@"
            ;;
        history)
            cmd_history "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}未知命令: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"