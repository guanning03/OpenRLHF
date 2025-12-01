#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
把 Instruct 模型的 chat_template 安装/复制到 base 模型上。

假设目录：
- Base:      /work/models/Llama-3.1-8B
- Instruct:  /work/models/Llama-3.1-8B-Instruct

运行：
    python install_llama_chat_template.py

效果：
- 从 Instruct 目录读取 chat_template：
    1) tokenizer_config.json["chat_template"]，如果有；
    2) 否则读取 chat_template.jinja 文件。
- 写入到 Base 目录的 tokenizer_config.json["chat_template"]；
- 在 Base 目录生成 chat_template.jinja（内容相同）；
- 给 Base 的 tokenizer_config.json 备份一份 *.bak。
"""

import json
from pathlib import Path
import shutil
import sys


# 你给的两个路径
BASE_MODEL_DIR = Path("/work/models/Llama-3.1-8B")
INSTRUCT_MODEL_DIR = Path("/work/models/Llama-3.1-8B-Instruct")


def load_template_from_instruct():
    """从 Instruct 模型目录里拿到 chat_template 字符串。"""
    tok_cfg_path = INSTRUCT_MODEL_DIR / "tokenizer_config.json"
    jinja_path = INSTRUCT_MODEL_DIR / "chat_template.jinja"

    template_text = None

    # 1) 优先从 tokenizer_config.json 里读 chat_template
    if tok_cfg_path.exists():
        with tok_cfg_path.open("r", encoding="utf-8") as f:
            cfg = json.load(f)
        template_text = cfg.get("chat_template", None)

    # 2) 如果 json 里没有，再尝试读 chat_template.jinja 文件
    if not template_text and jinja_path.exists():
        template_text = jinja_path.read_text(encoding="utf-8")

    if not template_text:
        raise RuntimeError(
            f"在 {INSTRUCT_MODEL_DIR} 里既找不到 tokenizer_config.json 里的 "
            f'"chat_template"，也没有 chat_template.jinja 文件。'
        )

    return template_text


def install_template_to_base(template_text: str):
    """把 template 写入 base 模型的 tokenizer_config.json 和 chat_template.jinja。"""
    tok_cfg_path = BASE_MODEL_DIR / "tokenizer_config.json"
    if not tok_cfg_path.exists():
        raise RuntimeError(
            f"在 base 模型目录 {BASE_MODEL_DIR} 下找不到 tokenizer_config.json，"
            "无法写入 chat_template。"
        )

    # 备份原始 tokenizer_config.json
    backup_path = tok_cfg_path.with_suffix(tok_cfg_path.suffix + ".bak")
    shutil.copy2(tok_cfg_path, backup_path)
    print(f"[INFO] 已备份 tokenizer_config.json -> {backup_path}")

    # 写入 chat_template 字段
    with tok_cfg_path.open("r", encoding="utf-8") as f:
        cfg = json.load(f)

    cfg["chat_template"] = template_text

    with tok_cfg_path.open("w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)

    print(f"[INFO] 已在 {tok_cfg_path} 中写入 chat_template 字段。")

    # 另外生成一份 chat_template.jinja（可选，但很方便）
    base_jinja_path = BASE_MODEL_DIR / "chat_template.jinja"
    base_jinja_path.write_text(template_text, encoding="utf-8")
    print(f"[INFO] 已生成 {base_jinja_path}")


def optional_test():
    """可选的小测试：检查 base 模型能不能读到 chat_template。"""
    try:
        from transformers import AutoTokenizer
    except ImportError:
        print("[WARN] 没安装 transformers，跳过测试。")
        return

    try:
        tok = AutoTokenizer.from_pretrained(str(BASE_MODEL_DIR))
    except Exception as e:
        print(f"[WARN] 无法加载 Base 模型 tokenizer：{e}")
        return

    tmpl = getattr(tok, "chat_template", None)
    if not tmpl:
        print("[WARN] 加载 tokenizer 后 chat_template 还是空的，请检查。")
    else:
        print("[INFO] 测试成功，tokenizer.chat_template 非空。")
        # 只打印前 200 个字符，防止太长
        preview = tmpl[:200].replace("\n", "\\n")
        print(f"[INFO] 模板前 200 字符预览：\n{preview}")


def main():
    # 基础检查
    if not INSTRUCT_MODEL_DIR.exists():
        print(f"[ERROR] Instruct 模型目录不存在: {INSTRUCT_MODEL_DIR}")
        sys.exit(1)

    if not BASE_MODEL_DIR.exists():
        print(f"[ERROR] Base 模型目录不存在: {BASE_MODEL_DIR}")
        sys.exit(1)

    print(f"[INFO] Instruct 模型目录: {INSTRUCT_MODEL_DIR}")
    print(f"[INFO] Base 模型目录:     {BASE_MODEL_DIR}")

    # 1) 从 Instruct 模型读取模板
    template_text = load_template_from_instruct()
    print("[INFO] 已从 Instruct 模型读取 chat_template。")

    # 2) 写入 Base 模型
    install_template_to_base(template_text)

    # 3) 可选：简单测试一下
    optional_test()
    print("[DONE] 模板安装完成。")


if __name__ == "__main__":
    main()
