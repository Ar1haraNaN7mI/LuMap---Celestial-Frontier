import Foundation

/// Dependency-free Office Open XML export. All slide text remains editable;
/// the full spoken lesson, sources and quiz answer keys travel as speaker notes.
/// Audio/video are separate exports so the PPTX stays portable and small.
enum LessonPresentationExporter {
    static func data(deck: NarratedLearningDeck) throws -> Data {
        var files: [(String, Data)] = []
        func add(_ path: String, _ xml: String) { files.append((path, Data((declaration + xml).utf8))) }
        let slideOverrides = deck.slides.indices.map { index in
            "<Override PartName=\"/ppt/slides/slide\(index + 1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/><Override PartName=\"/ppt/notesSlides/notesSlide\(index + 1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml\"/>"
        }.joined()
        add("[Content_Types].xml", """
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/><Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/><Override PartName="/ppt/notesMasters/notesMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.notesMaster+xml"/><Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>\(slideOverrides)</Types>
        """)
        add("_rels/.rels", relationships([
            ("rId1", "officeDocument", "ppt/presentation.xml"),
            ("rId2", "metadata/core-properties", "docProps/core.xml"),
            ("rId3", "extended-properties", "docProps/app.xml")
        ]))
        add("docProps/core.xml", "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:title>\(escape(deck.title))</dc:title><dc:creator>Lumap · Celestial Frontier</dc:creator><dc:description>\(escape(deck.subtitle))</dc:description></cp:coreProperties>")
        add("docProps/app.xml", "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\"><Application>Lumap</Application><PresentationFormat>On-screen Show (16:9)</PresentationFormat><Slides>\(deck.slides.count)</Slides><Notes>\(deck.slides.count)</Notes></Properties>")
        let ids = deck.slides.indices.map { "<p:sldId id=\"\(256 + $0)\" r:id=\"rId\($0 + 3)\"/>" }.joined()
        add("ppt/presentation.xml", "<p:presentation \(namespaces)><p:sldMasterIdLst><p:sldMasterId id=\"2147483648\" r:id=\"rId1\"/></p:sldMasterIdLst><p:notesMasterIdLst><p:notesMasterId r:id=\"rId2\"/></p:notesMasterIdLst><p:sldIdLst>\(ids)</p:sldIdLst><p:sldSz cx=\"12192000\" cy=\"6858000\" type=\"screen16x9\"/><p:notesSz cx=\"6858000\" cy=\"9144000\"/></p:presentation>")
        var presentationRels = [("rId1", "slideMaster", "slideMasters/slideMaster1.xml"), ("rId2", "notesMaster", "notesMasters/notesMaster1.xml")]
        presentationRels += deck.slides.indices.map { ("rId\($0 + 3)", "slide", "slides/slide\($0 + 1).xml") }
        add("ppt/_rels/presentation.xml.rels", relationships(presentationRels))
        add("ppt/slideMasters/slideMaster1.xml", "<p:sldMaster \(namespaces)><p:cSld><p:spTree>\(group)</p:spTree></p:cSld>\(colorMap)<p:sldLayoutIdLst><p:sldLayoutId id=\"2147483649\" r:id=\"rId1\"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>")
        add("ppt/slideMasters/_rels/slideMaster1.xml.rels", relationships([("rId1", "slideLayout", "../slideLayouts/slideLayout1.xml"), ("rId2", "theme", "../theme/theme1.xml")]))
        add("ppt/slideLayouts/slideLayout1.xml", "<p:sldLayout \(namespaces) type=\"blank\" preserve=\"1\"><p:cSld name=\"Lumap Lesson\"><p:spTree>\(group)</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>")
        add("ppt/slideLayouts/_rels/slideLayout1.xml.rels", relationships([("rId1", "slideMaster", "../slideMasters/slideMaster1.xml")]))
        add("ppt/notesMasters/notesMaster1.xml", "<p:notesMaster \(namespaces)><p:cSld><p:spTree>\(group)</p:spTree></p:cSld>\(colorMap)<p:notesStyle/></p:notesMaster>")
        add("ppt/notesMasters/_rels/notesMaster1.xml.rels", relationships([("rId1", "theme", "../theme/theme1.xml")]))
        add("ppt/theme/theme1.xml", theme)
        for (offset, slide) in deck.slides.enumerated() {
            let number = offset + 1
            add("ppt/slides/slide\(number).xml", slideXML(slide, total: deck.slides.count))
            add("ppt/slides/_rels/slide\(number).xml.rels", relationships([("rId1", "slideLayout", "../slideLayouts/slideLayout1.xml"), ("rId2", "notesSlide", "../notesSlides/notesSlide\(number).xml")]))
            var notes = [slide.narration]
            if let quiz = slide.quiz {
                notes += ["RETRIEVAL CHECK", quiz.prompt, quiz.options.map { "\($0.id). \($0.text)" }.joined(separator: "\n"), "ANSWER: \(quiz.correctOptionID). \(quiz.explanation)"]
            }
            if let sourceLabel = deck.sourceLabel { notes += ["SOURCES", sourceLabel] }
            let body = shape(id: 2, name: "Teaching script", x: 54, y: 100, width: 612, height: 820,
                             paragraphs: notes.flatMap { $0.components(separatedBy: "\n") }, size: 1400, color: "172036", placeholder: "<p:ph type=\"body\" idx=\"1\"/>")
            add("ppt/notesSlides/notesSlide\(number).xml", "<p:notes \(namespaces)><p:cSld><p:spTree>\(group)\(body)</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:notes>")
            add("ppt/notesSlides/_rels/notesSlide\(number).xml.rels", relationships([("rId1", "notesMaster", "../notesMasters/notesMaster1.xml"), ("rId2", "slide", "../slides/slide\(number).xml")]))
        }
        return try storedZIP(files)
    }

    private static func slideXML(_ slide: NarratedDeckSlide, total: Int) -> String {
        var content = group
        content += shape(id: 2, name: "Chapter", x: 64, y: 44, width: 1100, height: 34, paragraphs: ["LUMAP  /  \(slide.eyebrow.uppercased())"], size: 1100, color: "56D6BA", bold: true)
        content += shape(id: 3, name: "Title", x: 64, y: 95, width: 1140, height: 134, paragraphs: [slide.title], size: slide.title.count > 75 ? 2800 : 3400, color: "F5F7FC", bold: true)
        content += shape(id: 4, name: "Learning points", x: 64, y: 252, width: 610, height: 336, paragraphs: slide.bullets.map { "•  " + $0 }, size: 2200, color: "D5DCEE")
        content += shape(id: 5, name: "Concept", x: 730, y: 248, width: 486, height: 262, paragraphs: [slide.visual.primaryLabel, "↓", slide.visual.secondaryLabel], size: 2300, color: "E5FFF5", bold: true, fill: "142B3C")
        if let quiz = slide.quiz {
            content += shape(id: 6, name: "Retrieval question", x: 64, y: 604, width: 1150, height: 65, paragraphs: ["PAUSE & THINK  ·  \(quiz.prompt)"], size: 1300, color: "8BE4CE")
        }
        content += shape(id: 7, name: "Page number", x: 64, y: 680, width: 1150, height: 24, paragraphs: ["CELESTIAL FRONTIER                                                        \(slide.index) / \(total)"], size: 850, color: "91A0BD")
        return "<p:sld \(namespaces)><p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val=\"0D1425\"/></a:solidFill><a:effectLst/></p:bgPr></p:bg><p:spTree>\(content)</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>"
    }

    private static func shape(id: Int, name: String, x: Int, y: Int, width: Int, height: Int, paragraphs: [String], size: Int, color: String, bold: Bool = false, fill: String? = nil, placeholder: String = "") -> String {
        let fillXML = fill.map { "<a:solidFill><a:srgbClr val=\"\($0)\"/></a:solidFill>" } ?? "<a:noFill/>"
        let text = paragraphs.map { paragraph in
            "<a:p><a:pPr><a:spcAft><a:spcPts val=\"1200\"/></a:spcAft></a:pPr><a:r><a:rPr lang=\"en-US\" sz=\"\(size)\" b=\"\(bold ? 1 : 0)\"><a:solidFill><a:srgbClr val=\"\(color)\"/></a:solidFill><a:latin typeface=\"Arial\"/><a:ea typeface=\"PingFang SC\"/></a:rPr><a:t>\(escape(paragraph))</a:t></a:r><a:endParaRPr lang=\"en-US\" sz=\"\(size)\"/></a:p>"
        }.joined()
        return "<p:sp><p:nvSpPr><p:cNvPr id=\"\(id)\" name=\"\(escape(name))\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr>\(placeholder)</p:nvPr></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"\(x * 9525)\" y=\"\(y * 9525)\"/><a:ext cx=\"\(width * 9525)\" cy=\"\(height * 9525)\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>\(fillXML)<a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr wrap=\"square\" lIns=\"120000\" tIns=\"50000\" rIns=\"120000\" bIns=\"50000\"><a:normAutofit/></a:bodyPr><a:lstStyle/>\(text)</p:txBody></p:sp>"
    }

    private static let declaration = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
    private static let namespaces = "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\""
    private static let group = "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>"
    private static let colorMap = "<p:clrMap accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\" accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\" bg1=\"lt1\" bg2=\"lt2\" folHlink=\"folHlink\" hlink=\"hlink\" tx1=\"dk1\" tx2=\"dk2\"/>"
    private static let theme = """
    <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Lumap"><a:themeElements><a:clrScheme name="Lumap"><a:dk1><a:srgbClr val="0D1425"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="172036"/></a:dk2><a:lt2><a:srgbClr val="F5F7FC"/></a:lt2><a:accent1><a:srgbClr val="56D6BA"/></a:accent1><a:accent2><a:srgbClr val="8174FF"/></a:accent2><a:accent3><a:srgbClr val="5695E9"/></a:accent3><a:accent4><a:srgbClr val="F0C574"/></a:accent4><a:accent5><a:srgbClr val="EC8AB1"/></a:accent5><a:accent6><a:srgbClr val="91A0BD"/></a:accent6><a:hlink><a:srgbClr val="8174FF"/></a:hlink><a:folHlink><a:srgbClr val="56D6BA"/></a:folHlink></a:clrScheme><a:fontScheme name="Lumap"><a:majorFont><a:latin typeface="Arial"/><a:ea typeface="PingFang SC"/><a:cs typeface=""/></a:majorFont><a:minorFont><a:latin typeface="Arial"/><a:ea typeface="PingFang SC"/><a:cs typeface=""/></a:minorFont></a:fontScheme><a:fmtScheme name="Lumap"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>
    """

    private static func relationships(_ values: [(String, String, String)]) -> String {
        let entries = values.map { id, type, target in
            let base = type == "metadata/core-properties" ? "http://schemas.openxmlformats.org/package/2006/relationships/" : "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"
            return "<Relationship Id=\"\(id)\" Type=\"\(base)\(type)\" Target=\"\(target)\"/>"
        }.joined()
        return "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\(entries)</Relationships>"
    }

    private static func escape(_ value: String) -> String {
        // XML 1.0 excludes U+FFFE/U+FFFF as well as most C0 controls.
        // Valid Unicode text can contain these scalars in uploaded material.
        String(value.unicodeScalars.filter {
            [9, 10, 13].contains($0.value) || (0x20...0xD7FF).contains($0.value)
                || (0xE000...0xFFFD).contains($0.value) || (0x10000...0x10FFFF).contains($0.value)
        })
            .replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func storedZIP(_ files: [(String, Data)]) throws -> Data {
        var result = Data(), central = Data()
        func little<T: FixedWidthInteger>(_ value: T) -> Data {
            var value = value.littleEndian
            return withUnsafeBytes(of: &value) { Data($0) }
        }
        func crc32(_ bytes: Data) -> UInt32 {
            var crc: UInt32 = 0xFFFFFFFF
            for byte in bytes {
                crc ^= UInt32(byte)
                for _ in 0..<8 { crc = (crc >> 1) ^ (0xEDB88320 & (0 &- (crc & 1))) }
            }
            return ~crc
        }
        for (path, bytes) in files {
            let name = Data(path.utf8), checksum = crc32(bytes), offset = UInt32(result.count), size = UInt32(bytes.count)
            result += little(UInt32(0x04034B50)) + little(UInt16(20)) + little(UInt16(0x0800)) + little(UInt16(0))
            result += little(UInt16(0)) + little(UInt16(0x0021)) + little(checksum) + little(size) + little(size)
            result += little(UInt16(name.count)) + little(UInt16(0)) + name + bytes
            central += little(UInt32(0x02014B50)) + little(UInt16(20)) + little(UInt16(20)) + little(UInt16(0x0800)) + little(UInt16(0))
            central += little(UInt16(0)) + little(UInt16(0x0021)) + little(checksum) + little(size) + little(size)
            central += little(UInt16(name.count)) + little(UInt16(0)) + little(UInt16(0)) + little(UInt16(0)) + little(UInt16(0)) + little(UInt32(0)) + little(offset) + name
        }
        let centralOffset = UInt32(result.count)
        result += central
        result += little(UInt32(0x06054B50)) + little(UInt16(0)) + little(UInt16(0)) + little(UInt16(files.count)) + little(UInt16(files.count))
        result += little(UInt32(central.count)) + little(centralOffset) + little(UInt16(0))
        return result
    }
}
