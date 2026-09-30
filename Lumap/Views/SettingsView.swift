import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
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
    @State private var exportPath: String?
    @State private var launchAtLogin = false
    @State private var loginStatusMessage: String?
    @State private var showingHistoryImporter = false
    @State private var historyImportMessage: String?
    @State private var didLoadLaunchAtLogin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(
                    eyebrow: "LOCAL-FIRST CONTROL",
                    title: store.t("Settings", "设置"),
                    subtitle: store.t("Interface, teaching language, model provider and observation permissions are controlled independently.", "界面语言、教学语言、模型供应商和观察权限可以独立控制。")
                )

                HStack(alignment: .top, spacing: 18) {
                    languageCard
                    accessibilityCard
                }
                providerCard
                HStack(alignment: .top, spacing: 18) {
                    connectionsCard
                    localDataCard
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(LumapTheme.coral)
                }
            }
            .padding(LumapTheme.pagePadding)
            .frame(maxWidth: 1040, alignment: .leading)
        }
        .onAppear(perform: loadSettings)
        .fileImporter(
            isPresented: $showingHistoryImporter,
            allowedContentTypes: [.commaSeparatedText, .json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    do {
                        let count = try await store.importHistoryPreview(from: url)
                        historyImportMessage = store.t("Imported a privacy-preserving preview from \(count) records.", "已从 \(count) 条记录导入隐私保护预览。")
                    } catch { errorMessage = error.localizedDescription }
                }
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
    }

    private var languageCard: some View {
        LumapCard {
            VStack(alignment: .leading, spacing: 16) {
                Label(store.t("Language", "语言"), systemImage: "globe")
                    .font(.title3.bold())
                Picker(store.t("Interface", "界面"), selection: $interfaceLanguage) {
                    Text("English").tag(AppLanguage.english)
                    Text("简体中文").tag(AppLanguage.simplifiedChinese)
                }
                .onChange(of: interfaceLanguage) { _, value in
                    do { try store.updateInterfaceLanguage(value) }
                    catch { errorMessage = error.localizedDescription }
                }
                Picker(store.t("Teaching content", "教学内容"), selection: $learningLanguage) {
                    Text("English").tag(AppLanguage.english)
                    Text("简体中文").tag(AppLanguage.simplifiedChinese)
                }
                .onChange(of: learningLanguage) { _, value in
                    do { try store.updateLearningLanguage(value) }
                    catch { errorMessage = error.localizedDescription }
                }
                Label(store.t("English is the default on macOS.", "macOS 端默认使用英文。"), systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(LumapTheme.mint)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var accessibilityCard: some View {
        LumapCard {
            VStack(alignment: .leading, spacing: 16) {
                Label(store.t("Accessibility", "辅助功能"), systemImage: "accessibility")
                    .font(.title3.bold())
                Toggle(store.t("Reduce motion", "减少动态效果"), isOn: $reducedMotion)
                Toggle(store.t("Larger product text", "更大的产品文字"), isOn: $largeText)
                Button(store.t("Save accessibility", "保存辅助功能设置")) {
                    do { try store.updateAccessibility(reducedMotion: reducedMotion, largeText: largeText) }
                    catch { errorMessage = error.localizedDescription }
                }
                .buttonStyle(.bordered)
                Label(store.t("Persona animation obeys Reduce Motion.", "桌宠动画会遵循“减少动态效果”。"), systemImage: "figure.roll")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var providerCard: some View {
        LumapCard(padding: 24) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(store.t("Custom model API", "自定义模型 API"), systemImage: "network")
                            .font(.title3.bold())
                        Text(store.t("Narrated Deck uses the saved provider for live generation. If generation is unavailable, Lumap labels and restores the deterministic demo. API keys stay in macOS Keychain.", "讲解课件会使用保存的供应商进行实时生成。若生成服务不可用，Lumap 会明确标注并恢复确定性演示。API 密钥只保存在 macOS 钥匙串中。"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    PrototypeBadge(label: "LIVE GENERATION + FALLBACK")
                }

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Protocol").font(.caption.weight(.semibold))
                        Picker("Protocol", selection: $apiStyle) {
                            ForEach(ProviderAPIStyle.allCases) { style in Text(style.label).tag(style) }
                        }
                        .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Model").font(.caption.weight(.semibold))
                        TextField("model-name", text: $model).textFieldStyle(.roundedBorder)
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Endpoint").font(.caption.weight(.semibold))
                    TextField("https://api.example/v1", text: $endpoint).textFieldStyle(.roundedBorder)
                    Text(store.t("For Responses, a base ending in /v1 is resolved to /v1/responses automatically; a full /responses URL is also accepted.", "使用 Responses 时，以 /v1 结尾的基础地址会自动解析为 /v1/responses，也可以直接填写完整的 /responses 地址。"))
                        .font(.caption2)
                        .foregroundStyle(LumapTheme.secondaryInk)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("API key").font(.caption.weight(.semibold))
                    SecureField(store.hasSavedAPIKey ? "Saved key — leave blank to keep" : "Optional for a local endpoint", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Button(store.t("Save securely", "安全保存")) {
                        do {
                            try store.saveProvider(endpoint: endpoint, model: model, style: apiStyle, apiKey: apiKey)
                            apiKey = ""
                            errorMessage = nil
                        } catch { errorMessage = error.localizedDescription }
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        Task { await testDraftProvider() }
                    } label: {
                        if store.providerIsTesting { ProgressView().controlSize(.small) }
                        else { Label(store.t("Test connection", "测试连接"), systemImage: "bolt.horizontal.circle") }
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.providerIsTesting)
                    if store.hasSavedAPIKey {
                        Button(store.t("Remove saved key", "删除已保存密钥"), role: .destructive) {
                            do {
                                try store.deleteProviderAPIKey()
                                apiKey = ""
                                errorMessage = nil
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    Spacer()
                    Text(store.providerTestState)
                        .font(.caption)
                        .foregroundStyle(store.providerTestState.hasPrefix("Generation verified") ? LumapTheme.mint : .secondary)
                }
            }
        }
    }

    private var connectionsCard: some View {
        LumapCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(store.t("Connections", "连接"), systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.title3.bold())
                connectionRow(title: "Public profile links", status: store.t("Prototype preview", "原型预览"), icon: "link")
                connectionRow(title: "History file import", status: store.t("Available", "可用"), icon: "clock.arrow.circlepath")
                connectionRow(title: "Chrome extension", status: store.t("Prototype", "原型"), icon: "puzzlepiece.extension")
                Button {
                    showingHistoryImporter = true
                } label: {
                    Label(store.t("Import history CSV / JSON", "导入历史记录 CSV / JSON"), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                if let historyImportMessage {
                    Text(historyImportMessage).font(.caption).foregroundStyle(LumapTheme.mint)
                }
                Text(store.t("Browser extension pairing and continuous computer-use sensing remain disabled in this build.", "当前版本不会启用浏览器扩展配对或持续电脑使用监测。"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var localDataCard: some View {
        LumapCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(store.t("Local data", "本地数据"), systemImage: "externaldrive.fill")
                    .font(.title3.bold())
                Label(store.t("Independent Lumap SwiftData store", "独立的 Lumap SwiftData 数据库"), systemImage: "checkmark.shield.fill")
                    .font(.subheadline).foregroundStyle(LumapTheme.mint)
                Text("Bundle: com.local.lumap")
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                Toggle(store.t("Launch at login", "登录时启动"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        guard didLoadLaunchAtLogin else { return }
                        updateLoginItem(enabled)
                    }
                if let loginStatusMessage {
                    Text(loginStatusMessage).font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    do {
                        let url = try store.exportSnapshot()
                        exportPath = url.path
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } catch { errorMessage = error.localizedDescription }
                } label: {
                    Label(store.t("Export readable snapshot", "导出可读快照"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                if let exportPath {
                    Text(exportPath).font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t("Family profiles", "家庭档案")).font(.subheadline.weight(.semibold))
                        Text(store.t("Separate-profile registry follows the demo build", "独立档案注册表将在演示版之后接入"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    PrototypeBadge()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func connectionRow(title: String, status: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(LumapTheme.accent).frame(width: 24)
            Text(title).font(.subheadline)
            Spacer()
            Text(status).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    private func loadSettings() {
        interfaceLanguage = store.language
        learningLanguage = store.learningLanguage
        reducedMotion = store.profile?.reducedMotion ?? false
        largeText = store.profile?.largeText ?? false
        endpoint = store.providerEndpoint
        model = store.providerModel
        apiStyle = store.providerStyle
        launchAtLogin = SMAppService.mainApp.status == .enabled
        DispatchQueue.main.async { didLoadLaunchAtLogin = true }
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

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                loginStatusMessage = store.t("Login launch requested. macOS may require approval in System Settings.", "已请求登录时启动。macOS 可能要求在系统设置中批准。")
            } else {
                try SMAppService.mainApp.unregister()
                loginStatusMessage = store.t("Login launch disabled.", "登录时启动已关闭。")
            }
        } catch {
            loginStatusMessage = error.localizedDescription
            didLoadLaunchAtLogin = false
            launchAtLogin = SMAppService.mainApp.status == .enabled
            DispatchQueue.main.async { didLoadLaunchAtLogin = true }
        }
    }
}
