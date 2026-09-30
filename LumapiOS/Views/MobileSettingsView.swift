import SwiftUI
import UniformTypeIdentifiers

struct MobileSettingsView: View {
    @EnvironmentObject private var store: LumapStore
    @State private var interfaceLanguage: AppLanguage = .english
    @State private var learningLanguage: AppLanguage = .english
    @State private var reducedMotion = false
    @State private var largeText = false
    @State private var endpoint = ""
    @State private var model = ""
    @State private var apiStyle: ProviderAPIStyle = .openAIResponses
    @State private var apiKey = ""
    @State private var errorMessage: String?
    @State private var didLoad = false
    @State private var isShowingVoicePackImporter = false
    @State private var isImportingVoicePack = false
    @State private var voicePackIsInstalled = false
    @State private var voicePackMessage: String?
    @State private var showVoicePackSuccess = false

    var body: some View {
        Form {
            Section {
                Picker(store.t("Interface language", "界面语言"), selection: $interfaceLanguage) {
                    Text("English").tag(AppLanguage.english)
                    Text("简体中文").tag(AppLanguage.simplifiedChinese)
                }
                .onChange(of: interfaceLanguage) { _, value in
                    do { try store.updateInterfaceLanguage(value) } catch { errorMessage = error.localizedDescription }
                }

                Picker(store.t("Learning language", "教学语言"), selection: $learningLanguage) {
                    Text("English").tag(AppLanguage.english)
                    Text("简体中文").tag(AppLanguage.simplifiedChinese)
                }
                .onChange(of: learningLanguage) { _, value in
                    do { try store.updateLearningLanguage(value) } catch { errorMessage = error.localizedDescription }
                }
            } header: {
                Text(store.t("Language", "语言"))
            }

            Section {
                Toggle(store.t("Reduce motion", "减少动态效果"), isOn: $reducedMotion)
                Toggle(store.t("Larger in-app text", "更大的应用内文字"), isOn: $largeText)
            } header: {
                Text(store.t("Accessibility", "辅助功能"))
            } footer: {
                Text(store.t("Lumap also follows system Dynamic Type and VoiceOver settings.", "Lumap 也会遵循系统动态字体和 VoiceOver 设置。"))
            }
            .onChange(of: reducedMotion) { _, _ in saveAccessibility() }
            .onChange(of: largeText) { _, _ in saveAccessibility() }

            Section {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(voicePackIsInstalled
                            ? store.t("Kokoro voice ready", "Kokoro 语音已就绪")
                            : store.t("Kokoro voice pack required", "需要 Kokoro 语音包"))
                            .font(.headline)
                        Text(voicePackIsInstalled
                            ? store.t("Human-like narration runs privately on this device.", "拟人讲解会在此设备上私密运行。")
                            : store.t("Narrated Deck uses a silent timeline until a verified pack is imported.", "导入经过校验的语音包前，讲解课件会使用静音时间轴。"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: voicePackIsInstalled ? "waveform.circle.fill" : "waveform.badge.exclamationmark")
                        .foregroundStyle(voicePackIsInstalled ? MobileTheme.mint : MobileTheme.gold)
                }

                Button {
                    isShowingVoicePackImporter = true
                } label: {
                    if isImportingVoicePack {
                        HStack {
                            ProgressView()
                            Text(store.t("Importing voice pack…", "正在导入语音包……"))
                        }
                    } else {
                        Label(
                            voicePackIsInstalled
                                ? store.t("Replace from Extracted Folder", "从已解压文件夹替换")
                                : store.t("Import Extracted Kokoro Folder", "导入已解压的 Kokoro 文件夹"),
                            systemImage: "folder.badge.plus"
                        )
                    }
                }
                .disabled(isImportingVoicePack)

                if let voicePackMessage {
                    Text(voicePackMessage)
                        .font(.caption)
                        .foregroundStyle(voicePackIsInstalled ? MobileTheme.mint : .secondary)
                }
            } header: {
                Text(store.t("Open-source narration", "开源讲解语音"))
            } footer: {
                Text(store.t(
                    "Choose the already-extracted kokoro-int8-multi-lang-v1_1 folder. Lumap validates the required files and exact model sizes, copies only approved assets into its private container, and never uses a system voice.",
                    "请选择已解压的 kokoro-int8-multi-lang-v1_1 文件夹。Lumap 会校验必要文件及模型的精确大小，仅把允许的资源复制进应用私有容器，并且不会使用系统语音。"
                ))
            }

            Section {
                TextField("Endpoint", text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                TextField(store.t("Model name", "模型名称"), text: $model)
                    .textInputAutocapitalization(.never)
                Picker(store.t("API style", "API 类型"), selection: $apiStyle) {
                    ForEach(ProviderAPIStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                SecureField(store.t("API key (leave blank to keep saved key)", "API 密钥（留空则保留已保存密钥）"), text: $apiKey)
                    .textInputAutocapitalization(.never)

                Button(store.t("Save Provider", "保存供应商")) {
                    saveProvider()
                }
                Button {
                    Task { await testDraftProvider() }
                } label: {
                    if store.providerIsTesting {
                        HStack { ProgressView(); Text(store.t("Testing…", "正在测试……")) }
                    } else {
                        Text(store.t("Test Connection", "测试连接"))
                    }
                }
                .disabled(store.providerIsTesting)
                Text(store.providerTestState)
                    .font(.caption)
                    .foregroundStyle(store.providerTestState.hasPrefix("Generation verified") ? MobileTheme.mint : .secondary)
            } header: {
                Text(store.t("Custom AI provider", "自定义 AI 供应商"))
            } footer: {
                Text(store.t("Narrated Deck tries live generation, then visibly restores the deterministic demo if the service is unavailable. A base ending in /v1 is resolved to /v1/responses for Responses. The API key stays in this device's Keychain and is excluded from exports.", "讲解课件会先尝试实时生成；若服务不可用，会明确显示并恢复确定性演示。Responses 模式下，以 /v1 结尾的地址会解析为 /v1/responses。API 密钥保存在设备钥匙串中，不会包含在导出中。"))
            }

            Section {
                Label(store.t("Learning data stays in this app's local container.", "学习数据保存在此应用的本地容器中。"), systemImage: "internaldrive.fill")
                Label(store.t("Camera access is only relevant to a user-started spatial activity.", "只有用户主动启动空间活动时，摄像头权限才可能被使用。"), systemImage: "camera.fill")
                Label(store.t("The current spatial demo does not start a camera session.", "当前空间演示不会启动摄像头会话。"), systemImage: "eye.slash.fill")
            } header: {
                Text(store.t("Privacy", "隐私"))
            }
        }
        .navigationTitle(store.t("Settings", "设置"))
        .task { loadOnce() }
        .fileImporter(
            isPresented: $isShowingVoicePackImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            Task { await importVoicePack(from: result) }
        }
        .alert(store.t("Settings need attention", "设置需要处理"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(store.t("Kokoro voice is ready", "Kokoro 语音已就绪"), isPresented: $showVoicePackSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.t(
                "The verified pack is now inside Lumap. Close and reopen Narrated Deck to refresh its narration session.",
                "经过校验的语音包现已复制到 Lumap。请关闭并重新打开讲解课件，以刷新语音会话。"
            ))
        }
    }

    private func loadOnce() {
        guard !didLoad, let profile = store.profile else { return }
        didLoad = true
        interfaceLanguage = store.language
        learningLanguage = store.learningLanguage
        reducedMotion = profile.reducedMotion
        largeText = profile.largeText
        endpoint = store.providerEndpoint
        model = store.providerModel
        apiStyle = store.providerStyle
        voicePackIsInstalled = KokoroVoicePackManager.isInstalled()
        if voicePackIsInstalled {
            voicePackMessage = store.t(
                "Installed in Lumap's private Application Support folder.",
                "已安装到 Lumap 私有的 Application Support 文件夹。"
            )
        }
    }

    private func saveAccessibility() {
        guard didLoad else { return }
        do {
            try store.updateAccessibility(reducedMotion: reducedMotion, largeText: largeText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveProvider() {
        do {
            try store.saveProvider(endpoint: endpoint, model: model, style: apiStyle, apiKey: apiKey)
            apiKey = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func testDraftProvider() async {
        store.providerIsTesting = true
        defer { store.providerIsTesting = false }

        let enteredKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let configuration = ProviderConfiguration(
            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            style: apiStyle,
            apiKey: enteredKey.isEmpty ? (LumapKeychainStore.read(account: "active-provider") ?? "") : enteredKey
        )

        do {
            let result = try await LumapAIClient.test(configuration: configuration)
            store.providerTestState = "Generation verified · \(result)"
        } catch {
            store.providerTestState = "Configured · generation unavailable · \(error.localizedDescription)"
        }
    }

    private func importVoicePack(from result: Result<[URL], Error>) async {
        guard !isImportingVoicePack else { return }
        do {
            guard let selectedFolder = try result.get().first else {
                throw KokoroVoicePackImportError.unavailableSource
            }
            isImportingVoicePack = true
            defer { isImportingVoicePack = false }

            let hasSecurityScope = selectedFolder.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope {
                    selectedFolder.stopAccessingSecurityScopedResource()
                }
            }

            _ = try await KokoroVoicePackManager.importExtractedPack(from: selectedFolder)
            await NarrationSession.invalidateCachedVoiceEngine()
            voicePackIsInstalled = true
            voicePackMessage = store.t(
                "Verified and copied locally. Reopen Narrated Deck to use Kokoro.",
                "已完成校验并复制到本地。重新打开讲解课件即可使用 Kokoro。"
            )
            showVoicePackSuccess = true
        } catch {
            voicePackIsInstalled = KokoroVoicePackManager.isInstalled()
            errorMessage = error.localizedDescription
        }
    }
}
