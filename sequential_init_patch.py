#!/usr/bin/env python3
"""
OpenRLHF 串行初始化补丁
用于减少启动时的 PID 峰值

使用方法:
1. 备份原文件: cp openrlhf/cli/train_ppo_ray.py openrlhf/cli/train_ppo_ray.py.bak
2. 应用补丁: python3 sequential_init_patch.py
3. 运行训练: bash scripts/rlhf.sh
"""

import os
import shutil
from pathlib import Path

def apply_sequential_init_patch():
    """应用串行初始化补丁"""
    
    target_file = Path("openrlhf/cli/train_ppo_ray.py")
    
    if not target_file.exists():
        print(f"❌ 错误: 找不到文件 {target_file}")
        return False
    
    # 备份原文件
    backup_file = target_file.with_suffix('.py.original')
    if not backup_file.exists():
        print(f"📦 创建备份: {backup_file}")
        shutil.copy2(target_file, backup_file)
    else:
        print(f"⚠️  备份已存在: {backup_file}")
    
    # 读取文件
    with open(target_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 查找需要修改的代码段
    original_code = '''    # init reference/reward/actor model
    refs = []
    if ref_model is not None:
        refs.extend(ref_model.async_init_model_from_pretrained(strategy, args.pretrain))
    refs.extend(actor_model.async_init_model_from_pretrained(strategy, args.pretrain, max_steps, vllm_engines))
    if not args.remote_rm_url:
        refs.extend(reward_model.async_init_model_from_pretrained(strategy, reward_pretrain))
    ray.get(refs)'''
    
    # 新的串行初始化代码
    patched_code = '''    # init reference/reward/actor model
    # PATCHED: Sequential initialization to reduce PID peak
    print("🔄 串行初始化模型以减少 PID 峰值...")
    
    if ref_model is not None:
        print("  初始化 Reference Model...")
        ray.get(ref_model.async_init_model_from_pretrained(strategy, args.pretrain))
        print("  ✓ Reference Model 初始化完成")
    
    print("  初始化 Actor Model...")
    ray.get(actor_model.async_init_model_from_pretrained(strategy, args.pretrain, max_steps, vllm_engines))
    print("  ✓ Actor Model 初始化完成")
    
    if not args.remote_rm_url:
        print("  初始化 Reward Model...")
        ray.get(reward_model.async_init_model_from_pretrained(strategy, reward_pretrain))
        print("  ✓ Reward Model 初始化完成")
    
    print("✓ 所有模型初始化完成")'''
    
    if original_code in content:
        # 应用补丁
        new_content = content.replace(original_code, patched_code)
        
        # 写回文件
        with open(target_file, 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        print(f"✅ 补丁应用成功！")
        print(f"📝 原文件已备份到: {backup_file}")
        print()
        print("修改说明:")
        print("  - 将并发初始化改为串行初始化")
        print("  - Reference Model → Actor Model → Reward Model")
        print("  - 预期效果: PID 峰值降低 60-70%，但启动时间增加 2-3 倍")
        print()
        print("恢复原文件:")
        print(f"  cp {backup_file} {target_file}")
        return True
    else:
        print("❌ 错误: 未找到匹配的代码段")
        print("文件可能已被修改或版本不匹配")
        return False

def revert_patch():
    """恢复原始文件"""
    target_file = Path("openrlhf/cli/train_ppo_ray.py")
    backup_file = target_file.with_suffix('.py.original')
    
    if not backup_file.exists():
        print("❌ 错误: 找不到备份文件")
        return False
    
    shutil.copy2(backup_file, target_file)
    print(f"✅ 已恢复原始文件")
    return True

def main():
    import argparse
    parser = argparse.ArgumentParser(description="OpenRLHF 串行初始化补丁")
    parser.add_argument("--revert", action="store_true", help="恢复原始文件")
    args = parser.parse_args()
    
    print("=" * 60)
    print("OpenRLHF 串行初始化补丁")
    print("=" * 60)
    print()
    
    if args.revert:
        revert_patch()
    else:
        apply_sequential_init_patch()

if __name__ == "__main__":
    main()

