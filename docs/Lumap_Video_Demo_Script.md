# Lumap 产品演示录制脚本

版本 3.0 · Celestial Frontier · 2026-09-30

本版演示“只看当前小节，由模型逐步安排”的真实流程。内部计划按学习者生成 2–12 小节，每小节初始安排 1–3 种方式；用户看不到未来目录或总节数，也不能从全部方法中跳选。不同形式通过不同学习目标/背景生成的真实项目展示。具体题目以实际模型结果为准，不把固定答案贴到不相干的问题上。

录制准备可以较长，成片约 8 分钟。允许剪辑研究、生成和重复练习，但在画面标注“等待已剪辑”或“恢复之前完成的项目”。不能靠修改数据库、伪造已完成状态或恢复旧方法选择器来制造镜头。

## 录制前准备

1. Settings 使用 OpenAI Responses、`https://api.ikuncode.cc/v1/responses`、`gpt-5.6-sol`，测试真实生成。已有 Keychain 密钥不重新输入，不拍密钥或私人资料。演示无限额度不代表供应商免费调用。
2. 界面和教学语言使用 English。确认 Kokoro 包可用，试听完整旁白；缺包先安装。保留模型失败、停止和重试界面，不用系统 TTS 或固定成功课件替代。
3. 准备公开自有文本和 `DemoContent/Climate_Feedback_Loops_Demo.md`。后者是明确标识的合成上传材料，仅用于演示文件解析；对它的引用问答仍真实调用模型。
4. 按下面的学习背景建立不同项目。真实完成各项目的当前活动和必要前序步骤；当模型安排了要拍摄的方法时保留该项目，以后从 Personal 恢复。每个项目记录实际来源、当前小节、当前方法和已完成状态。
5. 测试 Mac 窗口正常与较窄布局；必要时折叠 Path/Lumi，保留可读字号。准备 iPhone Simulator 或已签名真机，并在其 Settings 配置模型和语音包。

### 可直接输入的真实学习目标

这些输入表达学习需求，模型仍负责选择内容范围和形式。若结果与示例安排不同，按实际安排录制，不能声称输入保证某个固定方法。

| 背景与输入 | 适合捕捉的真实变化 |
| --- | --- |
| `I am a beginner with 15 minutes. I want to understand photosynthesis: where the carbon in plant sugar comes from and what light contributes.` | 初学者小节、日常例子、具体误区与基础支持 |
| `I already know matrix multiplication. I have 20 minutes to understand eigenvectors through a simple 2 by 2 matrix and explain why the direction stays the same.` | 与上一目标不同的来源、例题和已有基础适配 |
| `I am a visual thinker learning the carbon cycle. I struggle to connect reservoirs and flows, and I need to explain those relationships clearly.` | 模型可能安排概念连接、类比或讲解复盘 |
| `I learn well by making decisions in a story. I want to recognise phishing messages and explain which evidence makes a message suspicious.` | 模型可能安排故事分支、误区诊断或迁移任务 |
| `I can explain negative feedback but forget the details a day later. Help me retrieve the ideas without seeing the answer first, then apply them to room temperature control.` | 模型可能安排主动回忆、迁移或补弱 |
| `I want a narrated visual lesson about photosynthesis with complete explanations and short questions to check my understanding. I am a beginner and have 15 minutes.` | 若本节安排 narratedDeck，录制完整课件、旁白与 Quiz |
| `I am investigating how light intensity changes photosynthesis. Help me predict what changes when one condition is different and design a fair experiment.` | 模型可能安排模拟、反事实、实践推理 |

录前记录表使用真实值：项目原始输入、背景设置、当前小节标题、模型分配的方法、已完成项、实际来源和生成时间。不要把“想展示某方式”误写成“模型已经分配了该方式”。

## 主版本：约 8 分钟

| 时间 | 操作 | 必须拍到的证据与口播重点 |
| --- | --- | --- |
| 0:00–0:30 | 首页输入光合作用目标，展示研究/编排过程，再剪辑到当前小节。 | 原始目标、真实来源、当前小节。口播：从问题开始，模型结合背景寻找适合现在的学习内容。 |
| 0:30–1:00 | 展开当前学习历程与本节安排，展示尚未完成时的 Next activity。 | 只显示当前节、已完成历史与未知下一步；没有未来目录或全部方法菜单，继续按钮此时不可用。 |
| 1:00–1:40 | 完成实际问题，先给一个相关误解，查看模型反馈，然后按屏幕安排做补救。 | 具体误区和分数；低分仍在同一小节。仅当题目问碳来源时可答“植物主要从土壤获得糖中的碳”，再修正为“糖中的碳来自二氧化碳”。 |
| 1:40–2:10 | 完成本节所有安排；可压缩重复操作，保留最后一个有效提交。点击 Next section，展示实际适配等待与新当前节。 | 已完成状态、唯一下一步、真实下一节生成。口播：不是预先展开一张路线图，而是利用刚才的回答重新安排下一节。 |
| 2:10–2:35 | 从 Personal 恢复准备好的特征向量项目；展示它的当前内容、来源和实际分配方式。 | 不同知识基础对应不同任务；恢复保留真实学习位置。没有点击未来节点或手动切换方法。 |
| 2:35–3:05 | 从 Personal 恢复已真实到达图解、故事、回忆或反事实活动的项目，拍摄各自一次操作。 | 不同 renderer 的真实输入与模型反馈。画面注明“恢复已准备项目”。故事可用自定义人物图，不宣称完整 Paper2Galgame 已嵌入。 |
| 3:05–3:55 | 恢复模型安排了 narratedDeck 的项目，显示多页与完整讲稿；播放完整一段、暂停/继续，并在章节结束后答 Quiz。 | 5–8 页、全文音频、章节末 Quiz。完整学习证据要求全部页面听完且所有题已回答；快进镜头不冒充已完整学习。 |
| 3:55–4:15 | 打开真实导出的 PPTX、教学稿和 MP4，查看中间及结尾。 | 多页与完整音轨；PPTX 讲者备注有全文。视频的题目是思考画面，应用内 Quiz 才可点击。 |
| 4:15–4:50 | Library 上传资料，进入 Guided Study；展开来源，并问 `Which claim is directly supported by these sources, and what remains uncertain?`。 | Guided Study 使用同一当前小节与安排，不是固定四步。真实引文与资料对应；不是调用 NotebookLM 私有服务。 |
| 4:50–5:10 | Knowledge Studio 勾选两份材料并提问，然后展示按所选资料建立的新项目。 | 实际资料选择、模型只引用所选 ID、原文短引文、当前小节；每份摘录有预算，不称为完整文档自动核验。 |
| 5:10–5:35 | 打开当前小节的可选 Theoretical/Practical 检测，再到 Personal/Adaptive Path 查看证据。 | 实际当前题目的模型反馈；正式检测可跳过，必需学习活动仍需完成。方法均分是观测，不是已证明的学习效率或训练后 RL。 |
| 5:35–5:55 | Interest 粘贴可公开读取的自有主页，确认或移除真实候选标签，刷新首页建议。 | 真实抓取与用户确认；登录墙或失败明确显示，不生成假成功。 |
| 5:55–6:20 | Handoff 导出当前会话文件，通过 Files/AirDrop 手动传到 iPhone 后导入。 | 当前小节、完成方法和回答恢复一致；未来仍隐藏，不重复奖励。明确手动文件接力，没有自动云同步。 |
| 6:20–6:45 | iPhone 打开当前活动并完成一个操作，展示只读安排卡和顺序继续按钮。 | 手机没有全部方法选择器；相同学习状态在窄屏可用。新生成和评估需要配置与网络。 |
| 6:45–7:10 | 单独打开 AR concept preview，操作锚点、滑杆与视觉层。 | 网格/粒子/热区即时反馈，保留 CONCEPT DEMO / CAMERA OFF / 2D FALLBACK。它不改变正常课程安排。 |
| 7:10–7:35 | Persona 开始学习模式、最小化窗口，触发摘要/另一种讲法/问题后恢复。 | 浮窗、计时、当前课程内容；没有声称正在读取外部电脑行为。 |
| 7:35–8:00 | 展示两份架构 PDF：先当前检索—规划—活动—反馈—下一节适配数据流，再介绍 LumaPath-RL 训练目标。 | 清晰区分运行中的 LLM＋本地约束和后续训练策略、空间硬件。结尾：One learner, one evolving path. |

架构文件使用仓库内的 [系统架构 PDF](pdf/Lumap_System_Architecture.pdf) 与 [LumaPath-RL 架构 PDF](pdf/Lumap_RL_Recommendation_Architecture.pdf)，不依赖仓库外的工作目录。

## 方法覆盖的补充镜头

以下是能力覆盖清单，不是用户的课程目录。只有某方式被模型安排为当前活动时才录制该行；否则通过真实学习目标/背景新建项目并完成其安排，或把该行留作待补镜头。不能在一门课中手动切换所有方式。

| 被安排的方式 | 拍摄操作 |
| --- | --- |
| Guided explanation | 读当前讲解，回答具体问题 |
| Worked example | 先预测，再揭示例题步骤并提交推理 |
| Socratic dialogue | 提交观点，显示模型基于上下文追问 |
| Analogy | 解释映射和类比失效处 |
| Visual map | 添加概念关系并说明连接 |
| Story | 加载本地人物图、选择剧情分支并解释理由 |
| Flash recall | 在揭晓前输入回忆，再核对并评估 |
| Teach back | 用自己的话讲解，查看遗漏反馈 |
| Simulation | 预测改变条件的影响，解释结果；不说成精确物理仿真 |
| Deliberate practice | 提交尝试、查看反馈、修正 |
| Reflection | 说明不确定处与下一行动 |
| Misconception diagnosis | 识别错误解释并修正 |
| Curiosity branch | 提出/选择与当前概念相关的问题，保存探索证据 |
| Counterfactual lab | 改变一个假设并比较结果 |
| Transfer challenge | 在新情境应用知识，给出理由 |
| Narrated lesson deck | 多页、全文旁白、章节 Quiz 与媒体导出 |
| Spatial AR（独立预览） | 锚点、滑杆、视觉反馈和显著预览标记，不混入已分配课程 |

## 故障镜头与录后验收

- 结构化课程/活动/评估/适配调用含修复共用 90 秒预算；活动等待显示秒数、Stop、失败和 Retry，另有 120 秒看门狗。网页检索、旁白生成和视频导出是独立阶段，不能说整个视频必在 90 秒内完成。
- 模型失败保留目标与证据。可以真实重试或恢复此前生成的缓存，不把固定样例标成新在线结果。
- 未完成当前活动不能继续；本节必需安排未完成不能显示下一节。恢复/导入后仍遵循该限制。
- 无网时可查看缓存课程、个人进度和已生成音频；新研究、生成、评分和对话需要网络。无语音包明确提示，不以字幕声称音频播放完成。
- 镜头中的题目、反馈、引用和任务必须互相对应；进度来自真实提交，截取少量素材不冒充长期学习效果。
- 最新验证快照：常规 60 项 macOS 测试中 58 项通过、2 项 opt-in 实时测试默认跳过、0 失败；macOS/iOS 构建通过。已独立完成真实双主题、正确/错误解释和双资料问答测试。
- 现有光合作用媒体实例为 6 页、2 个 Quiz、622 词讲稿、约 240.82 秒带音轨 MP4，见 `dist/Demos/Photosynthesis-Verification.json`。它证明一次完整媒体链可运行，不保证每个目标生成相同结构。
- 成片不出现密钥、私人资料或未授权页面；AR、训练后 RL、自动云同步和外部行为感知的边界保持准确。
