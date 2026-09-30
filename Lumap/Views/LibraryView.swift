import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var store: LumapStore
    @Query(sort: \MaterialRecord.importedAt, order: .reverse) private var materials: [MaterialRecord]
    @State private var showingImporter = false
    @State private var isImporting = false
    @State private var selectedMaterial: MaterialRecord?
    @State private var errorMessage: String?

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(store.t("Materials", "学习资料"))
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(22)
                Divider()
                if materials.isEmpty {
                    ContentUnavailableView(
                        store.t("No material yet", "还没有学习资料"),
                        systemImage: "doc.badge.plus",
                        description: Text(store.t("Import a PDF, TXT, Markdown, CSV or JSON file.", "导入 PDF、TXT、Markdown、CSV 或 JSON 文件。"))
                    )
                } else {
                    List(materials, selection: $selectedMaterial) { material in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(material.fileName, systemImage: material.fileType == "PDF" ? "doc.richtext.fill" : "doc.text.fill")
                                .font(.subheadline.weight(.semibold))
                            Text("\(material.fileType) · \(material.citationLabel)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .tag(material)
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(minWidth: 300, idealWidth: 340)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let material = selectedMaterial ?? materials.first {
                        HStack(alignment: .top) {
                            SectionHeader(
                                eyebrow: "TRACEABLE SOURCE",
                                title: material.fileName,
                                subtitle: "\(material.fileType) · \(material.citationLabel) · Imported \(material.importedAt.formatted(date: .abbreviated, time: .shortened))"
                            )
                            Spacer()
                            Text(material.status.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(LumapTheme.mint)
                        }
                        HStack {
                            Button {
                                do { try store.startGroundedStudy(from: material) }
                                catch { errorMessage = error.localizedDescription }
                            } label: {
                                Label(store.t("Start Guided Study", "开始引导学习"), systemImage: "text.book.closed.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            Button {
                                do {
                                    if store.currentGoal?.materialID == material.id {
                                        store.selectedSection = .studio
                                    } else {
                                        try store.startLearning(topic: "Learn from \(material.fileName)", materialID: material.id)
                                    }
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            } label: {
                                Label(store.t("Open in Studio", "在学习空间中打开"), systemImage: "rectangle.3.group.bubble.left")
                            }
                            .buttonStyle(.bordered)
                        }
                        LumapCard {
                            Text(material.excerpt)
                                .font(.body)
                                .textSelection(.enabled)
                                .lineLimit(32)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Label(store.t("The Hackathon build keeps the imported excerpt with a page/text label. Reopening the original file, OCR and complex figures remain Prototype.", "Hackathon 版本会保存导入摘录及页码或文本标签。重新打开原文件、OCR 和复杂图表仍为原型。"), systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView {
                            Label(store.t("Bring your own material", "导入你自己的资料"), systemImage: "books.vertical")
                        } description: {
                            Text(store.t("Lumap extracts readable text locally and stores the excerpt with a page or text-range label.", "Lumap 会在本地提取可读文本，并将摘录连同页码或文本范围标签一起保存。"))
                        } actions: {
                            Button(store.t("Import file", "导入文件")) { showingImporter = true }
                        }
                    }
                    if isImporting { ProgressView(store.t("Extracting locally…", "正在本地解析…")) }
                    if let errorMessage { Text(errorMessage).foregroundStyle(LumapTheme.coral) }
                }
                .padding(30)
                .frame(maxWidth: 840, alignment: .leading)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf, .plainText, .commaSeparatedText, .json],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else {
                if case .failure(let error) = result { errorMessage = error.localizedDescription }
                return
            }
            isImporting = true
            Task {
                defer { isImporting = false }
                do {
                    selectedMaterial = try await store.importMaterial(from: url)
                    errorMessage = nil
                } catch { errorMessage = error.localizedDescription }
            }
        }
    }
}
