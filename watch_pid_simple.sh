#!/bin/bash

# 简单的实时 watch 命令
# 用法: ./watch_pid_simple.sh

watch -n 0.5 '
echo "=== PID 状态实时监控 ==="
echo ""
echo "【系统 PID 限制】"
echo "  PID 上限:     $(cat /proc/sys/kernel/pid_max)"
echo "  最大线程数:   $(cat /proc/sys/kernel/threads-max)"
echo "  最后分配PID:  $(cat /proc/sys/kernel/ns_last_pid 2>/dev/null || echo "N/A")"
echo ""
echo "【当前使用情况】"
PROC_COUNT=$(ps -e --no-headers | wc -l)
THREAD_COUNT=$(ps -eL --no-headers | wc -l)
echo "  进程总数:     ${PROC_COUNT}"
echo "  线程总数:     ${THREAD_COUNT}"
echo ""
echo "【Ray 相关进程】"
RAY_PROCS=$(ps -ef | grep -E "ray|vllm" | grep -v grep | wc -l)
RAY_THREADS=$(ps -eLf | grep -E "ray|vllm" | grep -v grep | wc -l)
echo "  Ray 进程数:   ${RAY_PROCS}"
echo "  Ray 线程数:   ${RAY_THREADS}"
echo ""
echo "【PID 范围】"
echo "  最小 PID:     $(ps -e --no-headers -o pid | sort -n | head -1 | xargs)"
echo "  最大 PID:     $(ps -e --no-headers -o pid | sort -n | tail -1 | xargs)"
echo ""
echo "【最近创建的进程 (Top 5 PID)】"
ps -eo pid,ppid,nlwp,cmd --sort=-pid | head -6
'

