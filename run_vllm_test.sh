#!/bin/bash
# vLLM 测试运行脚本（带 PID 监控）

set -e

echo "=================================="
echo "vLLM 推理 PID 测试"
echo "=================================="
echo ""

# 配置
MODEL_PATH="/work/models/Llama-3-8b-sft-mixture"
NUM_SAMPLES=${1:-5000}
BATCH_SIZE=${2:-100}

# 检查模型是否存在
if [ ! -d "$MODEL_PATH" ]; then
    echo "❌ 错误: 模型路径不存在: $MODEL_PATH"
    exit 1
fi

# 创建日志目录
mkdir -p logs

# 生成日志文件名
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PID_LOG="logs/vllm_pid_${TIMESTAMP}.log"
TEST_LOG="logs/vllm_test_${TIMESTAMP}.log"

echo "配置:"
echo "  模型: $MODEL_PATH"
echo "  采样次数: $NUM_SAMPLES"
echo "  批处理大小: $BATCH_SIZE"
echo "  PID 日志: $PID_LOG"
echo "  测试日志: $TEST_LOG"
echo ""

# 启动 PID 监控（后台运行）
echo "启动 PID 监控..."
./monitor_pid.sh 0.5 > "$PID_LOG" 2>&1 &
MONITOR_PID=$!
echo "  监控进程 PID: $MONITOR_PID"
echo ""

# 等待一秒让监控稳定
sleep 1

# 运行测试
echo "开始 vLLM 测试..."
echo "=================================="
python3 test_vllm_advanced.py \
    --model "$MODEL_PATH" \
    --num-samples "$NUM_SAMPLES" \
    --batch-size "$BATCH_SIZE" \
    --tensor-parallel 1 \
    --max-tokens 50 \
    2>&1 | tee "$TEST_LOG"

# 等待几秒以观察推理后的状态
echo ""
echo "等待 3 秒以观察推理后状态..."
sleep 3

# 停止监控
echo ""
echo "停止 PID 监控..."
kill $MONITOR_PID 2>/dev/null || true
wait $MONITOR_PID 2>/dev/null || true

echo ""
echo "=================================="
echo "测试完成！"
echo "=================================="
echo ""
echo "日志文件:"
echo "  测试日志: $TEST_LOG"
echo "  PID 日志: $PID_LOG"
echo ""
echo "分析 PID 日志:"
echo "  查看加载阶段: grep -A 5 '模型加载' $TEST_LOG"
echo "  查看 PID 峰值: sort -t'|' -k2 -n $PID_LOG | tail -5"
echo ""

# 简单分析
echo "快速分析:"
echo "-----------"

# 提取关键信息
INITIAL_PID=$(head -3 "$PID_LOG" | tail -1 | awk -F'|' '{print $2}' | xargs)
PEAK_PID=$(sort -t'|' -k2 -n "$PID_LOG" | tail -1 | awk -F'|' '{print $2}' | xargs)
FINAL_PID=$(tail -1 "$PID_LOG" | awk -F'|' -k2 '{print $2}' | xargs)

if [ -n "$INITIAL_PID" ] && [ -n "$PEAK_PID" ]; then
    PID_INCREASE=$((PEAK_PID - INITIAL_PID))
    echo "初始 PID: $INITIAL_PID"
    echo "峰值 PID: $PEAK_PID"
    echo "最终 PID: $FINAL_PID"
    echo "PID 增长: $PID_INCREASE"
fi

echo ""
echo "💡 提示: 对比启动时和推理时的 PID 使用情况"

