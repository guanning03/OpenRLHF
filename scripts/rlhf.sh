# https://github.com/OpenRLHF/OpenRLHF/blob/main/examples/scripts/train_reinforce_llama_ray_hybrid_engine.sh

set -x

export WANDB_MODE=offline
export TORCH_SYMM_MEM_DISABLE_MULTICAST=1

MODEL_PATH=/work/models/
SAVE_PATH=/work/zzy/gz/OpenRLHF/results/

# Clean up previous Ray instances
# ray stop 

# Create logs directory
mkdir -p logs

# Generate log file with timestamp
LOG_FILE="logs/$(date +%Y%m%d_%H%M%S).log"

echo "Logging to: $LOG_FILE"

# ADV_ESTIMATOR=dr_grpo
ADV_ESTIMATOR=rloo
TEMPERATURE=1.0
### --init_kl_coef 1e-4

N_GPU=8

python3 -m openrlhf.cli.train_ppo_ray \
   --ref_num_nodes 1 \
   --ref_num_gpus_per_node ${N_GPU} \
   --reward_num_nodes 1 \
   --reward_num_gpus_per_node ${N_GPU} \
   --actor_num_nodes 1 \
   --actor_num_gpus_per_node ${N_GPU} \
   --vllm_num_engines 2 \
   --vllm_tensor_parallel_size 4 \
   --colocate_all_models \
   --vllm_gpu_memory_utilization 0.6 \
   --temperature ${TEMPERATURE} \
   --advantage_estimator ${ADV_ESTIMATOR} \
   --pretrain ${MODEL_PATH}/Llama-3.2-3B-Instruct \
   --reward_pretrain ${MODEL_PATH}/Llama-3-8b-rm-700k \
   --save_path ${SAVE_PATH}/final-3/llama3-8b-rlhf-${ADV_ESTIMATOR}-t${TEMPERATURE} \
   --ckpt_path ${SAVE_PATH}/ckpt/llama3-8b-rlhf-${ADV_ESTIMATOR}-t${TEMPERATURE} \
   --save_hf_ckpt \
   --micro_train_batch_size 8 \
   --train_batch_size 128 \
   --micro_rollout_batch_size 16 \
   --rollout_batch_size 512 \
   --n_samples_per_prompt 2 \
   --max_epochs 1 \
   --prompt_max_len 1024 \
   --max_samples 180000 \
   --generate_max_len 1024 \
   --zero_stage 3 \
   --save_steps 100 \
   --bf16 \
   --actor_learning_rate 5e-7 \
   --critic_learning_rate 9e-6 \
   --lr_scheduler constant \
   --lr_warmup_ratio 0.0 \
   --init_kl_coef 0.0 \
   --prompt_data OpenRLHF/prompt-collection-v0.1 \
   --input_key context_messages \
   --apply_chat_template \
   --normalize_reward \
   --gradient_checkpointing \
   --vllm_sync_backend nccl \
   --enforce_eager \
   --vllm_enable_sleep \
   --deepspeed_enable_sleep \
   --use_wandb "256879fdda25bc1fb8ee4f0310e71615e92f75c9" \
   --wandb_project "rlhf-1115" \
   2>&1 | tee "$LOG_FILE"

# You could also try
#   --use_kl_loss \
#   --kl_estimator k3 | k2 \

# also supports --advantage_estimator rloo | reinforce_baseline
