#!/usr/bin/env python3
"""
vLLM 高级采样测试脚本
支持自定义参数和批处理
"""

import argparse
import time
import os
from vllm import LLM, SamplingParams

def print_system_info():
    """打印系统信息"""
    print("\n系统信息:")
    print(f"  PID: {os.getpid()}")
    print(f"  当前 PID 上限: {open('/proc/sys/kernel/pid_max').read().strip()}")
    
    # 统计当前进程和线程数
    import subprocess
    proc_count = subprocess.check_output("ps -e --no-headers | wc -l", shell=True).decode().strip()
    thread_count = subprocess.check_output("ps -eL --no-headers | wc -l", shell=True).decode().strip()
    print(f"  系统进程数: {proc_count}")
    print(f"  系统线程数: {thread_count}")
    print()

def main():
    parser = argparse.ArgumentParser(description="vLLM 采样测试")
    parser.add_argument("--model", type=str, default="/work/models/Llama-3-8b-sft-mixture",
                        help="模型路径")
    parser.add_argument("--num-samples", type=int, default=5000,
                        help="采样次数")
    parser.add_argument("--batch-size", type=int, default=100,
                        help="批处理大小（分批处理以避免 OOM）")
    parser.add_argument("--tensor-parallel", type=int, default=1,
                        help="Tensor 并行大小")
    parser.add_argument("--max-tokens", type=int, default=100,
                        help="生成的最大 token 数")
    parser.add_argument("--temperature", type=float, default=0.8,
                        help="采样温度")
    parser.add_argument("--prompt", type=str, 
                        default="What is the capital of France? Answer briefly.",
                        help="测试问题")
    
    args = parser.parse_args()
    
    print("=" * 70)
    print("vLLM 高级采样测试")
    print("=" * 70)
    print(f"模型: {args.model}")
    print(f"采样次数: {args.num_samples}")
    print(f"批处理大小: {args.batch_size}")
    print(f"Tensor 并行: {args.tensor_parallel}")
    print(f"最大 tokens: {args.max_tokens}")
    print(f"温度: {args.temperature}")
    print("=" * 70)
    
    print_system_info()
    
    print("\n阶段 1: 模型加载")
    print("-" * 70)
    start_load = time.time()
    
    llm = LLM(
        model=args.model,
        tensor_parallel_size=args.tensor_parallel,
        gpu_memory_utilization=0.6,
        trust_remote_code=True,
        dtype="bfloat16",
        enforce_eager=True,
    )
    
    load_time = time.time() - start_load
    print(f"✓ 模型加载完成 (耗时: {load_time:.2f}秒)")
    
    print_system_info()
    
    # 设置采样参数
    sampling_params = SamplingParams(
        temperature=args.temperature,
        top_p=0.95,
        max_tokens=args.max_tokens,
        n=1,
    )
    
    print("\n阶段 2: 批量推理")
    print("-" * 70)
    print(f"问题: {args.prompt}")
    print()
    
    # 分批处理
    num_batches = (args.num_samples + args.batch_size - 1) // args.batch_size
    all_outputs = []
    total_inference_time = 0
    
    for batch_idx in range(num_batches):
        batch_start = batch_idx * args.batch_size
        batch_end = min((batch_idx + 1) * args.batch_size, args.num_samples)
        batch_size = batch_end - batch_start
        
        print(f"批次 {batch_idx + 1}/{num_batches}: 处理 {batch_size} 个样本...", end=" ")
        
        prompts = [args.prompt] * batch_size
        
        start = time.time()
        outputs = llm.generate(prompts, sampling_params)
        batch_time = time.time() - start
        total_inference_time += batch_time
        
        all_outputs.extend(outputs)
        
        throughput = batch_size / batch_time
        print(f"完成 ({batch_time:.2f}秒, {throughput:.1f} 样本/秒)")
    
    print()
    print("=" * 70)
    print("测试完成！")
    print("=" * 70)
    print(f"总采样次数: {len(all_outputs)}")
    print(f"推理总耗时: {total_inference_time:.2f}秒")
    print(f"平均每次耗时: {total_inference_time/len(all_outputs)*1000:.2f}ms")
    print(f"平均吞吐量: {len(all_outputs)/total_inference_time:.2f} 样本/秒")
    print()
    
    print_system_info()
    
    # 显示一些结果
    print("采样结果示例 (前 5 个):")
    print("-" * 70)
    for i, output in enumerate(all_outputs[:5]):
        generated_text = output.outputs[0].text.strip()
        print(f"[{i+1}] {generated_text[:80]}{'...' if len(generated_text) > 80 else ''}")
    
    print()
    print("💡 提示: 对比模型加载前后的系统信息，查看 PID/线程变化")

if __name__ == "__main__":
    main()

