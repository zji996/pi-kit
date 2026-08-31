# Pi Agent 上下文预算管理与长会话优化最佳实践指南

本指南总结了在大型项目及长会话场景下，针对 `@earendil-works/pi-coding-agent` 的上下文预算重构、思考等级策略、Prompt Cache 命中优化及工具链配置的核心经验。

---

## 1. 核心问题与设计哲学

在原生的上下文管理中，经常遇到以下痛点：
1. **多层预算割裂**：System 常驻提示词、Tool Schema、Tool 运行输出、LLM 摘要以及最新消息之间各自设定独立阈值，没有统一从总窗口中扣除。
2. **固定常数对大小模型不适**：硬编码的 `reserveTokens: 16k` 和 `keepRecentTokens: 20k` 对 32k 窗口容易死循环，对 200k/300k 大窗口又会滞留大量工具 dump 脏日志。
3. **摘要单调膨胀**：`PRESERVE all` 导致多次压缩后摘要自身变成无底洞。
4. **思考等级不匹配**：若摘要继承主对话的 `high` 思考，会导致摘要生成极慢、高耗 Token 甚至自身触发超时/溢出；若完全关闭思考，又会丢失复杂代码任务的关键结构化决策。

**推荐哲学**：将上下文视为**动态比例分配器**，并配合**分层衰减（Layered Eviction）**与**自适应 Low-Thinking 摘要**。

---

## 2. 动态统一预算分配方案

建议通过 `settings.json` 或动态计算器按模型窗口比例分配：

| 区域 | 建议比例 / 规则 | 作用 |
| :--- | :--- | :--- |
| **Output Reserve** | `max(maxTokens, thinkingBudget, 32768)` (封顶约 25% 窗口) | 为主模型提供充分的思考链输出与长代码生成空间 |
| **Working Memory** | `keepRecentTokens: 30000 ~ 40000` (约 30%~40% 剩余空间) | 保持最近 2~3 轮完整的工具调用与思考上下文 |
| **Summary Cap** | 封顶 4k ~ 8k tokens | 压缩摘要硬顶，旧任务完成项自动折叠 |
| **System Budget** | 封顶 8k ~ 12k tokens | 静态前缀、Skills 渐进披露（只放名称/一句话摘要，正文按需 read） |

### 推荐配置示例 (`~/.pi/agent/settings.json`)

```json
{
  "defaultProvider": "grok",
  "defaultModel": "grok-4.6",
  "defaultThinkingLevel": "high",
  "enableSkillCommands": true,
  "compaction": {
    "enabled": true,
    "reserveTokens": 32768,
    "keepRecentTokens": 40000
  },
  "packages": [
    "npm:pi-hashline-edit-pro",
    "npm:pi-web-access"
  ]
}
```

---

## 3. 摘要生成与 Low-Thinking 思考等级策略

- **主对话**：保持 `high` 思考等级，保障复杂编程、跨文件推理和复杂 Bug 排查的深度。
- **摘要与分支总结**：自适应切换为 `low` 思考等级。
  - **为什么不完全去掉？** 纯无思考模式下，模型对复杂的长轮次历史容易遗漏隐式决策和关键依赖变更。
  - **为什么不要 High 思考？** 摘要不需要超长 CoT，`low` 思考即可提供足够的归纳整理能力，耗时降低 70% 以上，显著减少超窗风险。
- **摘要去噪**：
  - 剔除历史中的 Thinking 过程块。
  - `write` / `edit` 等工具入参在摘要请求中只保留文件路径与变更行数，不塞入整篇代码。

---

## 4. Prompt Cache（前缀缓存）最大化命中准则

为了获得极低的首字延迟（TTFT）并大幅降低 API 成本，上下文管理必须遵守以下前缀缓存铁律：

1. **尽量保持同模型（Same Model）**：
   - 避免主对话用大模型、摘要切小模型；同一系列模型可以复用 System Prompt + Tools 的常驻热缓存。
2. **切忌逐轮滑动修改历史 Tool Result（Anti-pattern）**：
   - 前缀缓存是严格按字节顺序匹配的。如果每轮都去把 N 轮前的工具输出变成 stub，会导致该位置后的所有 Cache 彻底失效，每轮都在重新全量写入缓存。
   - **正确做法**：采用 **Epoch-based 阶梯式 / 批量裁剪**。只在触发 Compaction 切点时做一次性裁剪，平时保持 Append-Only。
3. **System Prompt 确定性**：
   - 保证 System Prompt 顶部静态稳定，避免插入每轮动态变动的当前时间戳或剩余 Token 数字。

---

## 5. 推荐工具链配置

- **`pi-hashline-edit-pro`**：
  - 基于行哈希与行范围的精确编辑工具，相较于纯文本匹配更抗上下文漂移与多处同名代码冲突。
- **`pi-web-access`**：
  - 提供实时搜索引擎与网页读取能力，按需补充最新文档。
