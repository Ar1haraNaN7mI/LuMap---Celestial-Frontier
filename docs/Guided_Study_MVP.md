# Lumap Guided Study MVP 技术说明

## 1 当前行为

Guided Study 是 Lumap 的本地资料驱动学习流程。用户可以从 Library 中已经导入的资料进入，也可以从当前主动目标进入。流程不新增网络请求，不调用任何第三方私有接口，所有提示、阶段推进和证据写入均在设备上完成。

四个阶段固定为：

1. **Understand / 理解资料**：识别核心主张、支持细节和未知范围，复用 `guidedExplanation`。
2. **Question / 追问假设**：提出可能推翻当前解释的问题，并引用触发问题的资料线索，复用 `socraticDialogue`。
3. **Retrieve / 主动回忆**：先隐藏资料回忆，再重新核对并修正，复用 `flashRecall`。
4. **Teach back / 讲解复盘**：向初学者解释概念、原因、资料支持的例子和下一项不确定性，复用 `teachBack`。

完成四阶段后，用户可以进入可选理论检测、Narrated Deck，或从全部 17 种 learning method 中选择下一项活动。

## 2 数据与证据合同

`GroundedStudyWorkflow` 是平台共用的确定性领域层。它负责阶段顺序、阶段到 `LearningMethod` 的映射、来源线索清理、双语提示和证据文本格式。

每次完成阶段会创建一个现有的 `ActivityRecord`：

- `goalID`：当前学习目标；
- `methodID`：该阶段复用的学习方法；
- `assistance`：`groundedStudy:<stage>`，用于区别普通方法活动；
- `artifactText`：阶段、方法、主题、来源、资料线索与用户回答；
- `rewardEventKey`：`grounded-study:<goalID>:<stage>`，保证阶段奖励幂等。

资料绑定目标时，来源显示 `fileName + citationLabel`，并使用本地保存的摘录生成不超过 220 字符的线索。没有资料时，界面明确显示来源为用户主动目标，不伪造页码或外部证据。

阶段必须按顺序提交。重复阶段不会重复写入或发奖；越级提交返回 `groundedStageUnavailable`。每个首次完成的阶段沿用现有目标进度与 `+10 Lumens` 奖励规则。

## 3 平台界面

### macOS

- 主侧栏提供 **Guided Study / 引导学习**。
- Library 的 **Start Guided Study** 绑定所选资料并进入流程。
- Learning Studio 工具栏可从当前目标进入。
- 自适应网格显示四阶段，避免小窗口横向溢出。
- 来源全文线索、全部方法和后续检测采用渐进披露；当前阶段只突出一个主动作“Save evidence & continue”。

### iOS / iPadOS

- Learn 页在当前目标下提供 **Open Guided Study**。
- 来源、路线、阶段回答和后续选项使用单列滚动布局。
- 主要按钮和菜单入口至少 44pt；阶段状态同时使用图标、文字和进度，不只依赖颜色。
- 完成后可直接提交现有理论检测，或返回 Studio 打开 Narrated Deck/其他方法。

## 4 当前边界

- 提示是本地规则文本，不是自动事实核验或生成式导师。
- 只使用当前绑定的一份资料摘录；没有跨资料检索、向量索引或 OCR。
- 引用入口指向 Lumap 已保存的 `citationLabel` 与摘录，当前不会重新打开原文件定位页面。
- 阶段完成证明用户提交了相应产出，不代表知识正确性；正式效果证据仍来自可选 assessment。
- 两端数据库目前相互独立，没有跨设备同步。

## 5 自动化验证

单元测试覆盖：

- 四阶段顺序、当前阶段、下一阶段与进度；
- 越级提交拒绝、重复提交幂等和奖励不重复；
- `MaterialRecord` 与目标绑定；
- 引用标签、资料线索与回答进入活动证据；
- 四阶段分别复用 guided explanation、Socratic dialogue、flash recall 与 teach-back。
- 即使现有目标的五步进度在流程中先达到 100%，仍可保存剩余引导阶段；目标保持完成状态，阶段奖励继续按独立事件键去重。
