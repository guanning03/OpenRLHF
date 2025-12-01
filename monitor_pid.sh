#!/bin/bash

# PID 监控脚本
# 用法: ./monitor_pid.sh [间隔秒数，默认0.5]

INTERVAL=${1:-0.5}
LOG_FILE="pid_monitor_$(date +%Y%m%d_%H%M%S).log"

echo "=== PID 监控工具 ==="
echo "监控间隔: ${INTERVAL}秒"
echo "日志文件: ${LOG_FILE}"
echo "按 Ctrl+C 停止"
echo ""

# 写入日志头
echo "时间戳,最后分配PID,PID上限,进程总数,线程总数,PID利用率(%)" > "${LOG_FILE}"

# 获取初始值
INITIAL_PID=$(cat /proc/sys/kernel/ns_last_pid 2>/dev/null || echo "N/A")
INITIAL_PROCS=$(ps -e --no-headers | wc -l)
INITIAL_THREADS=$(ps -eL --no-headers | wc -l)

echo "初始状态:"
echo "  最后分配PID: ${INITIAL_PID}"
echo "  进程数: ${INITIAL_PROCS}"
echo "  线程数: ${INITIAL_THREADS}"
echo ""
echo "开始实时监控..."
echo "----------------------------------------"
printf "%-19s | %-10s | %-8s | %-8s | %-10s | %-8s\n" "时间" "最后PID" "PID上限" "进程数" "线程数" "利用率%"
echo "----------------------------------------"

# 持续监控
while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    CURRENT_PID=$(cat /proc/sys/kernel/ns_last_pid 2>/dev/null || echo "0")
    PID_MAX=$(cat /proc/sys/kernel/pid_max)
    PROC_COUNT=$(ps -e --no-headers 2>/dev/null | wc -l)
    THREAD_COUNT=$(ps -eL --no-headers 2>/dev/null | wc -l)
    
    # 计算利用率（粗略估计）
    if [ "$CURRENT_PID" != "N/A" ] && [ "$CURRENT_PID" -gt 0 ]; then
        UTILIZATION=$(awk "BEGIN {printf \"%.2f\", ($CURRENT_PID / $PID_MAX) * 100}")
    else
        UTILIZATION="N/A"
    fi
    
    # 屏幕输出
    printf "%-19s | %-10s | %-8s | %-8s | %-10s | %-8s\n" \
        "${TIMESTAMP}" "${CURRENT_PID}" "${PID_MAX}" "${PROC_COUNT}" "${THREAD_COUNT}" "${UTILIZATION}"
    
    # 写入日志
    echo "${TIMESTAMP},${CURRENT_PID},${PID_MAX},${PROC_COUNT},${THREAD_COUNT},${UTILIZATION}" >> "${LOG_FILE}"
    
    sleep "${INTERVAL}"
done

