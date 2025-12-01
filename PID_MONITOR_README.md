# PID 监控工具使用说明

## 三种监控方案

### 方案1: 简单实时监控 (推荐快速查看)
```bash
./watch_pid_simple.sh
```
- 使用 `watch` 命令，每 0.5 秒刷新一次
- 显示：PID 限制、当前使用、Ray 进程统计、最近创建的进程
- 适合：快速查看系统状态
- 按 `Ctrl+C` 退出

---

### 方案2: 基础监控脚本
```bash
./monitor_pid.sh [间隔秒数]

# 示例：每 0.5 秒记录一次
./monitor_pid.sh 0.5

# 示例：每 1 秒记录一次
./monitor_pid.sh 1
```
- 实时输出到终端 + 保存到日志文件
- 记录：时间戳、最后PID、进程数、线程数、利用率
- 日志文件：`pid_monitor_YYYYMMDD_HHMMSS.log`
- 适合：长期监控和后续分析

---

### 方案3: 详细监控脚本 (推荐启动程序时使用)
```bash
./monitor_pid_detailed.sh [进程名关键字]

# 示例：监控 ray 相关进程
./monitor_pid_detailed.sh "ray"

# 示例：监控 python 进程
./monitor_pid_detailed.sh "python"

# 示例：监控多个关键字
./monitor_pid_detailed.sh "ray\|vllm\|python"
```
- 追踪 PID 激增和回绕事件
- 统计匹配进程的数量
- 计算总共分配了多少 PID
- 日志文件：`pid_detailed_YYYYMMDD_HHMMSS.log`
- 适合：调试 PID 耗尽问题

---

## 完整监控流程

### 步骤1: 启动监控（在一个终端）
```bash
cd /work/zzy/gz/OpenRLHF

# 选择详细监控
./monitor_pid_detailed.sh "ray\|vllm" | tee startup_monitor.log
```

### 步骤2: 启动你的程序（在另一个终端）
```bash
cd /work/zzy/gz/OpenRLHF

# 启动你的 Ray/RLHF 程序
bash scripts/rlhf.sh
```

### 步骤3: 观察监控输出
监控脚本会实时显示：
- PID 分配速度
- PID 激增警告（一次增加超过 10 个）
- PID 回绕警告（到达上限重新开始）
- Ray 进程和线程数量变化

### 步骤4: 分析结果
程序启动完成后，查看日志：
```bash
# 查看总共分配了多少 PID
grep "已分配" pid_detailed_*.log

# 查看是否有回绕
grep "回绕" pid_detailed_*.log

# 查看 PID 激增事件
grep "激增" pid_detailed_*.log
```

---

## 一键监控命令

### 单行命令 - 实时查看 PID 变化
```bash
while true; do 
    echo "$(date '+%H:%M:%S') | PID: $(cat /proc/sys/kernel/ns_last_pid) | 进程: $(ps -e --no-headers | wc -l) | 线程: $(ps -eL --no-headers | wc -l)"
    sleep 0.5
done
```

### 单行命令 - 监控 Ray 进程
```bash
watch -n 1 "ps -ef | grep -E 'ray|vllm' | grep -v grep | wc -l; ps -eLf | grep -E 'ray|vllm' | grep -v grep | wc -l"
```

---

## 同时监控多个指标

在不同终端窗口同时运行：

**终端1** - PID 监控
```bash
./monitor_pid_detailed.sh "ray\|vllm"
```

**终端2** - 系统资源监控
```bash
watch -n 1 'free -h; echo ""; ps aux --sort=-%mem | head -10'
```

**终端3** - 启动程序
```bash
bash scripts/rlhf.sh
```

---

## 故障排查

### 如果看到 "PID 回绕" 警告
说明 PID 到达上限（65535），需要提高限制：
```bash
sudo sysctl -w kernel.pid_max=4194304
```

### 如果看到大量 "PID 激增" 警告
说明程序在短时间内创建了很多进程/线程，这是正常的（Ray 特性），
但确保 pid_max 足够大。

### 查看历史峰值
```bash
# 从日志中找出 PID 使用峰值
grep "已分配" pid_detailed_*.log | tail -1
```

---

## 性能影响说明

- `watch_pid_simple.sh`: 几乎无影响（读取 /proc 文件）
- `monitor_pid.sh`: 极低影响（每秒几次 ps 命令）
- `monitor_pid_detailed.sh`: 低影响（包含 grep 过滤）

所有脚本都可以在生产环境安全使用。

