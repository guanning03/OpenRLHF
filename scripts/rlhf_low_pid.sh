#!/bin/bash
# OpenRLHF 启动脚本 - 低 PID 优化版
# 适用于 pid_max=65535 的环境

set -x

MODEL_PATH=/work/models/
SAVE_PATH=/work/zzy/gz/OpenRLHF/results/

# Clean up previous Ray instances
ray stop 

# Create logs directory
mkdir -p logs

# Generate log file with timestamp
LOG_FILE="logs/$(date +%Y%m%d_%H%M%S)_low_pid.log"

echo "Logging to: $LOG_FILE"
echo "=== 低 PID 优化配置 ==="
echo "1. 启用 Ray 的慢启动模式"
echo "2. 减少并发 worker 数量"
echo "3. 延长初始化超时"
echo ""

# 设置 Ray 环境变量优化 PID 使用
export RAY_BACKEND_LOG_LEVEL=warning
export RAY_worker_register_timeout_seconds=300  # 增加 worker 注册超时
export OMP_NUM_THREADS=4  # 限制 OpenMP 线程数

python3 -m openrlhf.cli.train_ppo_ray \
   --ref_num_nodes 1 \
   --ref_num_gpus_per_node 8 \
   --reward_num_nodes 1 \
   --reward_num_gpus_per_node 8 \
   --actor_num_nodes 1 \
   --actor_num_gpus_per_node 8 \
   --vllm_num_engines 1 \
   --vllm_tensor_parallel_size 8 \
   --colocate_all_models \
   --vllm_gpu_memory_utilization 0.55 \
   --advantage_estimator dr_grpo \
   --pretrain ${MODEL_PATH}/Llama-3-8b-sft-mixture \
   --reward_pretrain ${MODEL_PATH}/Llama-3-8b-rm-700k \
   --save_path ${SAVE_PATH}/final/llama3-8b-rlhf \
   --ckpt_path ${SAVE_PATH}/ckpt/llama3-8b-rlhf \
   --save_hf_ckpt \
   --micro_train_batch_size 4 \
   --train_batch_size 64 \
   --micro_rollout_batch_size 8 \
   --rollout_batch_size 64 \
   --n_samples_per_prompt 4 \
   --max_epochs 1 \
   --prompt_max_len 1024 \
   --max_samples 100000 \
   --generate_max_len 1024 \
   --zero_stage 3 \
   --bf16 \
   --actor_learning_rate 5e-7 \
   --critic_learning_rate 9e-6 \
   --init_kl_coef 0.0 \
   --prompt_data OpenRLHF/prompt-collection-v0.1 \
   --input_key context_messages \
   --apply_chat_template \
   --normalize_reward \
   --gradient_checkpointing \
   --packing_samples \
   --vllm_sync_backend nccl \
   --enforce_eager \
   --vllm_enable_sleep \
   --deepspeed_enable_sleep \
   --use_wandb "256879fdda25bc1fb8ee4f0310e71615e92f75c9" \
   --wandb_project "rlhf-1115-low-pid" \
   2>&1 | tee "$LOG_FILE"

echo ""
echo "=== 启动完成 ==="
echo "日志文件: $LOG_FILE"

