#!/bin/bash

# 详细 PID 监控脚本 - 追踪特定进程
# 用法: ./monitor_pid_detailed.sh [进程名关键字，如 ray 或 python]

PROCESS_FILTER=${1:-"ray\|python"}
INTERVAL=0.5
LOG_FILE="pid_detailed_$(date +%Y%m%d_%H%M%S).log"

echo "=== 详细 PID 监控工具 ==="
echo "过滤进程: ${PROCESS_FILTER}"
echo "监控间隔: ${INTERVAL}秒"
echo "日志文件: ${LOG_FILE}"
echo ""

# 初始统计
echo "初始系统状态:" | tee "${LOG_FILE}"
echo "  PID 上限: $(cat /proc/sys/kernel/pid_max)" | tee -a "${LOG_FILE}"
echo "  最后分配: $(cat /proc/sys/kernel/ns_last_pid 2>/dev/null || echo 'N/A')" | tee -a "${LOG_FILE}"
echo "  总进程数: $(ps -e --no-headers | wc -l)" | tee -a "${LOG_FILE}"
echo "  总线程数: $(ps -eL --no-headers | wc -l)" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"

# 记录启动前的最后 PID
START_PID=$(cat /proc/sys/kernel/ns_last_pid 2>/dev/null || echo "0")
START_TIME=$(date +%s)

echo "开始监控... (按 Ctrl+C 停止)" | tee -a "${LOG_FILE}"
echo "======================================" | tee -a "${LOG_FILE}"

# 监控循环
LAST_PID=$START_PID
MAX_PID=$START_PID
PID_ALLOCATED=0

while true; do
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    CURRENT_PID=$(cat /proc/sys/kernel/ns_last_pid 2>/dev/null || echo "0")
    PID_MAX=$(cat /proc/sys/kernel/pid_max)
    
    # 统计匹配的进程
    MATCHED_PROCS=$(ps -ef | grep -E "${PROCESS_FILTER}" | grep -v grep | wc -l)
    MATCHED_THREADS=$(ps -eLf | grep -E "${PROCESS_FILTER}" | grep -v grep | wc -l)
    
    # 计算 PID 增长
    if [ "$CURRENT_PID" -gt "$LAST_PID" ]; then
        PID_DELTA=$((CURRENT_PID - LAST_PID))
        PID_ALLOCATED=$((PID_ALLOCATED + PID_DELTA))
        
        # 记录大的增长
        if [ "$PID_DELTA" -gt 10 ]; then
            echo "[${CURRENT_TIME}] 🚀 PID 激增: +${PID_DELTA} (${LAST_PID} → ${CURRENT_PID})" | tee -a "${LOG_FILE}"
        fi
    elif [ "$CURRENT_PID" -lt "$LAST_PID" ]; then
        # PID 回绕了
        PID_DELTA=$((PID_MAX - LAST_PID + CURRENT_PID))
        PID_ALLOCATED=$((PID_ALLOCATED + PID_DELTA))
        echo "[${CURRENT_TIME}] ⚠️  PID 回绕! (${LAST_PID} → ${CURRENT_PID})" | tee -a "${LOG_FILE}"
    fi
    
    # 更新最大值
    if [ "$CURRENT_PID" -gt "$MAX_PID" ]; then
        MAX_PID=$CURRENT_PID
    fi
    
    # 每秒输出摘要
    ELAPSED=$(($(date +%s) - START_TIME))
    if [ $((ELAPSED % 2)) -eq 0 ] && [ "$LAST_PID" != "$CURRENT_PID" ]; then
        USAGE=$(awk "BEGIN {printf \"%.2f\", ($CURRENT_PID / $PID_MAX) * 100}")
        echo "[${CURRENT_TIME}] PID: ${CURRENT_PID}/${PID_MAX} (${USAGE}%) | 匹配进程: ${MATCHED_PROCS} | 线程: ${MATCHED_THREADS} | 已分配: ${PID_ALLOCATED}" | tee -a "${LOG_FILE}"
    fi
    
    LAST_PID=$CURRENT_PID
    sleep "${INTERVAL}"
done

