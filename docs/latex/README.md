# Lumap LaTeX 架构文档

本目录包含两份可复现的技术文档源文件：

- `Lumap_RL_Recommendation_Architecture.tex`：LumaPath-RL 的 POMDP/CMDP 定义、状态与奖励模型、CQL/actor/constraint 损失、OPE 指标、发布门槛和 TikZ 架构图。
- `Lumap_System_Architecture.tex`：macOS/iOS 当前运行架构、数据与信任边界、Recommendation Plane 目标架构、跨端降级路径和 TikZ 部署图。

公式均使用 LaTeX 原生数学环境，架构图均由 TikZ 生成；PDF 中的文字、公式和图形保持矢量输出。当前编译脚本使用 Tectonic 的 XeTeX 引擎，并自动重复编译以解析目录、编号和交叉引用。

```bash
brew install tectonic
cd Lumap
./Scripts/compile-architecture-pdfs.sh
```

输出文件：

- `docs/pdf/Lumap_RL_Recommendation_Architecture.pdf`
- `docs/pdf/Lumap_System_Architecture.pdf`

文档优先使用 macOS 自带的中文与拉丁字体。在其他平台编译时，可将源文件中的字体声明替换为本机等价字体；公式和 TikZ 图本身不依赖外部图片或网络资源。
