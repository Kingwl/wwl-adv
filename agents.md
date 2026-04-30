# WWL Adventure — Agent 协作入口

如果你是 Agent（Claude / Cursor / Copilot 等），**请先读 `docs/agents.md`**，然后再动手改代码。

## 必读文档

| 文档 | 什么时候读 |
|------|-----------|
| [`docs/agents.md`](./docs/agents.md) | **每次进入项目时先读** — 快速定位、修改路径、标准流程、测试规范 |
| [`docs/architecture.md`](./docs/architecture.md) | 需要了解场景树、信号流、碰撞层级、数据类时 |
| [`docs/game_design.md`](./docs/game_design.md) | 需要了解数值设计、核心循环、未来规划时 |

> **关键纪律**：修改武器相关代码后，必须运行 `./tests/run_tests.sh` 并确保 0 failed。详见 `docs/agents.md` 测试规范章节。
> **进度记录**：有重要进展（新增系统、完成阶段性目标、通过关键测试）时，更新 `docs/milestone.md`。

## 项目一句话

Godot 4.x 吸血鬼幸存者 like 实时生存 Roguelike，当前有 20 种武器、生命源泉等 9 种局内角色强化、1 种基础追踪敌人、升级三选一和武器流派系统，用 WASD/方向键移动，自动攻击，击杀升级。

## 快速启动

按 **F5** 运行项目，主菜单点击"开始游戏"。
