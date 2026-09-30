# Lumap 开源拟人语音技术方案

版本：1.1

更新：2026-09-30

状态：已确定引擎、模型、分发边界与应用接入接口

## 1. 选型结论

Lumap 当前的 Narrated Deck 课件旁白采用 **Kokoro + sherpa-onnx**；Persona 提示与知识点复述是后续接入目标。应用不调用 `AVSpeechSynthesizer`，也不会在模型缺失或生成失败时静默切换到 Apple 系统语音。

- **Kokoro** 是 82M 参数的开放权重 TTS 模型，权重采用 Apache 许可，适合本地运行并允许商业原型使用。
- **sherpa-onnx** 提供 Apache-2.0 许可的离线推理运行时和正式 Swift Package；同一包支持 iOS 15+ 与 macOS 10.15+。
- 当前固定使用 `sherpa-onnx 1.13.8` 和 `kokoro-int8-multi-lang-v1_1`。该 INT8 模型支持中文、英文与中英混说，24 kHz，103 个说话人。官方归档为 `147,031,220` 字节；其中 `model.int8.onnx` 必须为 `114,299,010` 字节，`voices.bin` 必须为 `53,790,720` 字节，两者合计 `168,089,730` 字节，完整解压目录还包含词典、FST、eSpeak 数据和许可证。

官方来源：

- sherpa-onnx Swift Package：<https://github.com/k2-fsa/sherpa-onnx/blob/master/Package.swift>
- sherpa-onnx 许可证：<https://github.com/k2-fsa/sherpa-onnx/blob/master/LICENSE>
- Kokoro 中英模型和试听：<https://k2-fsa.github.io/sherpa/onnx/tts/all/Chinese-English/kokoro-multi-lang-v1_1.html>
- Kokoro 模型卡与许可证说明：<https://huggingface.co/hexgrad/Kokoro-82M>

## 2. 为什么不用系统 TTS

系统 TTS 适合作为无依赖的辅助功能，但声音质量、语气与跨设备一致性受系统安装语音影响，难以形成 Lumap 的产品人格。Kokoro 允许 Lumap 固定声音、速度与停顿策略，并在 macOS 与 iOS 上离线生成相同风格的音频。离线推理也让学习材料无需发送到第三方语音服务。

当语音包未安装时，播放器仍显示课件、时间线、字幕和 Quiz；播放按钮显示“需要开源语音包”，并提供安装说明。此状态不会伪装成已经产生真实语音。

## 3. 运行架构

```text
Narrated Deck（当前）/ Persona（目标）
            │
            ▼
   NarrationProviding 协议
            │
            ├── SherpaKokoroNarrationProvider
            │      ├── 按固定文件、类型与大小规则校验语音包
            │      ├── 缓存 sherpa-onnx engine 并串行生成 Float PCM
            │      ├── 通过生成回调响应取消请求
            │      └── AVAudioPlayer 播放
            │
            └── VoicePackRequiredNarrationProvider
                   └── 显式返回安装状态；不使用系统 TTS
```

建议接口只暴露产品语义，不把 sherpa 类型传到界面层：

```swift
@MainActor
protocol NarrationProviding: AnyObject {
    var availability: NarrationAvailability { get }
    var playbackState: NarrationPlaybackState { get }
    var progress: Double { get }
    func play(_ request: NarrationRequest)
    func pause()
    func resume()
    func stop()
    func setMuted(_ muted: Bool)
}
```

生成工作在后台任务执行；UI 状态更新回到 `MainActor`。运行时按语音包目录惰性创建并缓存一个 Kokoro engine，所有生成请求经过同一串行执行边界，避免并发调用同一个 sherpa 实例。停止播放、切页或关闭课件会取消待处理任务；生成回调检测到取消后返回停止信号，丢弃未完成音频。一张幻灯片对应一个短音频片段，方便下一页、暂停、重播和随机 Quiz 插入。

## 4. 模型包与安装

模型权重不进入 Git，也不进入 macOS 或 iOS app bundle。仓库只保存审阅过的清单：

```text
VoicePacks/Kokoro/manifest.json
```

在 macOS 演示机执行：

```bash
cd /path/to/VoiceRecord/Lumap
./Scripts/install-kokoro-voice-pack.sh
```

默认安装位置是 Lumap 的 macOS Sandbox 容器：

```text
~/Library/Containers/com.local.lumap/Data/Library/Application Support/
  Lumap/VoicePacks/kokoro-int8-multi-lang-v1_1/
```

也可以指定目录：

```bash
./Scripts/install-kokoro-voice-pack.sh --destination /chosen/VoicePacks
```

macOS 安装器固定官方 k2-fsa URL，要求归档恰好为 `147,031,220` 字节并校验 SHA-256 `a1e94694776049035c4f2c6529f003aaece993c76aae9a78995831c3c4dcafc6`，拒绝危险的归档路径，也不会下载未知镜像或自动运行归档中的脚本。安装完成前还会执行下列目录校验：

- `model.int8.onnx`：普通文件，恰好 `114,299,010` 字节；
- `voices.bin`：普通文件，恰好 `53,790,720` 字节；
- 普通文件：`tokens.txt`、`lexicon-us-en.txt`、`lexicon-zh.txt`、`date-zh.fst`、`number-zh.fst`、`phone-zh.fst`、`LICENSE`；
- 目录：`espeak-ng-data`。

任一项目缺失或尺寸不符时，安装或导入会失败，运行时保持“需要开源语音包”的静音预览状态。

开发阶段推荐声线：

| 场景 | speaker id | 官方名称 | 用途 |
| --- | ---: | --- | --- |
| 英文 / 中英混合 | 0 | `af_maple` | 课件旁白与演示默认声线 |
| 中文 | 3 | `zf_001` | 中文学习内容默认声线 |

声线应允许用户试听后选择；未得到用户同意时不做声音克隆，也不收集用户录音。

## 5. macOS 与 iOS 接入

Xcode 工程通过 Swift Package Manager 固定依赖 `https://github.com/k2-fsa/sherpa-onnx` 的 `1.13.8` 版本和 `sherpa-onnx` product。官方包按平台选择 macOS/iOS XCFramework，并同时引入匹配的 ONNX Runtime。

macOS 使用仓库内的 `Scripts/install-kokoro-voice-pack.sh`。安装器负责下载或接收用户通过 `--archive` 指定的官方归档，完成归档摘要、路径安全、必需文件和精确尺寸校验，然后安装到 macOS 沙盒的 Application Support。应用本身不下载模型。

iOS 的发行边界是用户主动导入，不捆绑权重，也不在应用内下载权重：

1. 用户从清单固定的官方来源取得归档，在应用外核对归档 SHA-256，并先完整解压；
2. 在 Lumap 的 **Settings** 中选择语音包导入操作，选中包含 `model.int8.onnx` 的已解压 `kokoro-int8-multi-lang-v1_1` 根目录；
3. Lumap 使用安全作用域访问所选目录，执行第 4 节列出的必需文件与精确尺寸校验；
4. 校验通过后，应用把目录复制到自身的 `Application Support/Lumap/VoicePacks/kokoro-int8-multi-lang-v1_1/`。校验失败时不替换现有有效语音包。

iOS 导入完成后，需要退出并重新打开 **Narrated Deck**，让该页面重新创建 `NarrationSession` 并检测新语音包；当前版本不会热刷新已经打开的讲解会话。

## 6. 播放与失败策略

- 首次初始化显示“正在载入开源声音”；初始化后缓存 TTS engine，后续幻灯片复用同一实例并串行生成。
- 讲解播放采用 24 kHz 单声道 PCM；页面切换时立即停止旧片段。
- 音频开始播放后，暂停、恢复、停止和音量控制由播放器处理；若在生成阶段取消，恢复时会重新发起该页生成。
- iOS 播放前将 `AVAudioSession` 配置为 `.playback` category 和 `.spokenAudio` mode，使系统按口语内容处理输出；会话结束后释放激活状态。
- 停止、切页或离开页面会取消排队或正在进行的生成；生成回调尽快终止 sherpa 推理，已产生但不再需要的临时 WAV 会被删除。
- 生成失败时保留字幕和当前页面，显示可重试错误，不将失败记录为完成活动。
- macOS 安装器遇到归档哈希不匹配时拒绝安装；iOS 导入器或运行时遇到必需文件、精确尺寸或许可证校验失败时拒绝加载并提示重新安装。
- Reduce Motion 只影响波形动画，不影响播放；VoiceOver 可读取同一份字幕文本。

## 7. 许可证与更新

应用发行时需要保留 sherpa-onnx 和模型包内的 Apache-2.0 许可证与版权通知。每一个模型版本都使用独立清单，记录 URL、大小、SHA-256、兼容引擎版本和许可证。当前没有应用内自动更新：macOS 通过更新后的固定清单与安装器安装新版本，iOS 由用户重新导入新目录；两条路径都必须先完成自检，再替换有效语音包，不能直接覆盖正在使用的文件。

语音模型与 Lumap 的大模型 API 是两条独立链路。用户配置的模型 API 负责生成幻灯片内容、讲稿和 Quiz；Kokoro 只在本地把已生成讲稿转换为声音，API key 不会传给语音引擎。

## 8. 当前限制

- iOS 只接受已经解压的目录，不解压 `.tar.bz2`，也不提供模型下载、后台传输或自动更新。
- iOS 导入器校验必需路径以及模型和声纹的精确尺寸；归档级 SHA-256 必须在解压前由用户或受控分发流程核对，当前版本不为每个解压文件维护独立摘要。
- 新导入的语音包不会注入已经打开的 `NarrationSession`；必须关闭并重新进入 **Narrated Deck**。
- 每张幻灯片需要先在本机完成 WAV 生成再开始播放，目前不是流式 TTS。首次创建 engine 仍可能出现可见等待，并受设备性能和可用内存影响。
- 当前只提供清单指定的固定英文／中英混合与中文声线映射；没有声音克隆、录音采集或云端语音回退。
