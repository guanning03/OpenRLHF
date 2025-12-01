#!/usr/bin/env python3
"""
vLLM 采样测试脚本
用于测试推理阶段的 PID 使用情况
"""

import time
from vllm import LLM, SamplingParams

def main():
    print("=" * 60)
    print("vLLM 采样测试")
    print("=" * 60)
    
    # 模型路径
    model_path = "/work/models/Llama-3-8b-sft-mixture"
    
    print(f"\n1. 加载模型: {model_path}")
    print("   请在另一个终端运行 PID 监控...")
    print("   例如: ./monitor_pid.sh 0.5")
    print()
    
    start_load = time.time()
    
    # 初始化 vLLM
    llm = LLM(
        model=model_path,
        tensor_parallel_size=1,  # 单卡推理
        gpu_memory_utilization=0.6,
        trust_remote_code=True,
        dtype="bfloat16",
        enforce_eager=True,  # 避免额外的编译开销
    )
    
    load_time = time.time() - start_load
    print(f"✓ 模型加载完成 (耗时: {load_time:.2f}秒)")
    print()
    
    # 设置采样参数
    sampling_params = SamplingParams(
        temperature=0.8,
        top_p=0.95,
        max_tokens=100,
        n=1,  # 每个 prompt 生成 1 个响应
    )
    
    # 测试问题
    prompt = "What is the capital of France? Answer briefly."
    
    print(f"2. 测试问题: {prompt}")
    print(f"3. 开始采样 5000 次...")
    print()
    
    # 创建 5000 个相同的 prompt（模拟大批量推理）
    prompts = [prompt] * 5000
    
    start_inference = time.time()
    
    # 批量推理
    outputs = llm.generate(prompts, sampling_params)
    
    inference_time = time.time() - start_inference
    
    print("=" * 60)
    print("测试完成！")
    print("=" * 60)
    print(f"总采样次数: {len(outputs)}")
    print(f"推理总耗时: {inference_time:.2f}秒")
    print(f"平均每次耗时: {inference_time/len(outputs)*1000:.2f}ms")
    print(f"吞吐量: {len(outputs)/inference_time:.2f} 次/秒")
    print()
    
    # 显示前 3 个结果
    print("前 3 个采样结果:")
    for i, output in enumerate(outputs[:3]):
        prompt_text = output.prompt
        generated_text = output.outputs[0].text
        print(f"\n[{i+1}] Prompt: {prompt_text[:50]}...")
        print(f"    Response: {generated_text[:100]}...")
    
    print()
    print("提示: 检查 PID 监控日志，对比加载和推理阶段的 PID 使用情况")

if __name__ == "__main__":
    main()

