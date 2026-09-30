#!/usr/bin/env python3
"""Rebuild Lumap's README diagrams using only the Python standard library.

Run from any directory: python3 Scripts/generate-readme-diagrams.py
The diagrams document the implemented MVP, not a trained RL deployment.
"""

from html import escape
import json
import math
from pathlib import Path
import re
import textwrap


OUT = Path(__file__).resolve().parents[1] / "docs" / "images"
C = {
    "ink": "#20243B", "muted": "#596078", "indigo": "#5753C7",
    "teal": "#167B70", "line": "#C9CDD9", "canvas": "#F8F8F5",
    "soft": "#EEEFFA", "green": "#EAF5F0", "white": "#FFFFFF",
}


class Diagram:
    def __init__(self, width, height, title, description):
        self.parts = [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc">',
            f'<title id="title">{escape(title)}</title>',
            f'<desc id="desc">{escape(description)}</desc>',
        ]
        self.box(0, 0, width, height, C["canvas"], radius=0)

    def box(self, x, y, width, height, fill=None, stroke=None, radius=20):
        self.parts.append(
            f'<rect x="{x}" y="{y}" width="{width}" height="{height}" '
            f'rx="{radius}" fill="{fill or C["white"]}" '
            f'stroke="{stroke or "none"}" stroke-width="1.5"/>'
        )

    def text(self, x, y, value, size=23, fill=None, weight=400, anchor="start"):
        self.parts.append(
            f'<text x="{x}" y="{y}" font-family="-apple-system, BlinkMacSystemFont, '
            f'Segoe UI, Arial, sans-serif" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill or C["ink"]}" text-anchor="{anchor}">{escape(value)}</text>'
        )

    def lines(self, x, y, lines, size=23, gap=33, fill=None, weight=400):
        for index, line in enumerate(lines):
            self.text(x, y + index * gap, line, size, fill, weight)

    def path(self, data, color=None, dashed=False, arrow=True, teal=False):
        dash_attribute = 'stroke-dasharray="7 7"' if dashed else ""
        color = color or (C["teal"] if teal else C["muted"])
        self.parts.append(
            f'<path d="{data}" fill="none" stroke="{color}" '
            f'stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" '
            f'{dash_attribute}/>'
        )
        if arrow:
            # Explicit arrow strokes also render in macOS sips, which omits SVG markers.
            tokens = iter(re.findall(r"[MHV]|-?\d+(?:\.\d+)?", data))
            x = y = px = py = 0.0
            for command in tokens:
                px, py = x, y
                if command == "M":
                    x, y = float(next(tokens)), float(next(tokens))
                elif command == "H":
                    x = float(next(tokens))
                elif command == "V":
                    y = float(next(tokens))
                else:
                    raise ValueError(f"Unsupported path command {command}")
            length = ((x - px) ** 2 + (y - py) ** 2) ** 0.5
            ux, uy = (x - px) / length, (y - py) / length
            a = (x - ux * 8 - uy * 5, y - uy * 8 + ux * 5)
            b = (x - ux * 8 + uy * 5, y - uy * 8 - ux * 5)
            self.parts.append(
                f'<path d="M{a[0]:g} {a[1]:g} L{x:g} {y:g} L{b[0]:g} {b[1]:g}" '
                f'fill="none" stroke="{color}" stroke-width="2.5" '
                'stroke-linecap="round" stroke-linejoin="round"/>'
            )

    def save(self, name):
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT / name).write_text("\n".join(self.parts + ["</svg>"]) + "\n", encoding="utf-8")


def learning_loop():
    d = Diagram(
        1440, 1010, "Lumap: an adaptive learning loop",
        "A topic or selected document leads to source-grounded preparation and a current "
        "section with assigned learning methods. The learner responds, receives evaluation, "
        "and saves evidence. Gaps keep practice within the current section. Once its required "
        "methods are completed, the next eligible section is adapted using that evidence. "
        "Future section content stays hidden; completed history remains available.",
    )
    d.text(64, 68, "THE LEARNING EXPERIENCE", 18, C["indigo"], 700)
    d.text(64, 121, "A path that earns its next step", 42, weight=650)
    d.text(64, 161, "Different goals. Different methods. One focused section at a time.", 25, C["muted"])

    def card(x, y, number, title, lines, tag, accent=False):
        d.box(x, y, 396, 247, C["soft"] if accent else C["white"], C["line"])
        d.box(x + 24, y + 24, 42, 34, C["indigo"] if accent else C["soft"], radius=10)
        d.text(x + 45, y + 48, number, 18, C["white"] if accent else C["indigo"], 700, "middle")
        d.text(x + 24, y + 103, title, 30, weight=650)
        d.lines(x + 24, y + 142, lines, 23, 31, C["muted"])
        d.text(x + 24, y + 222, tag, 19, C["indigo"] if accent else C["teal"], 600)

    card(64, 214, "01", "Start with curiosity", ["Name a topic, explore an idea", "or bring your own document."], "Your intention takes priority")
    card(510, 214, "02", "Prepare with sources", ["Research the topic or use", "selected material excerpts."], "Goal + background + prior evidence")
    card(956, 214, "03", "Learn this section", ["Work through assigned methods:", "explain, map, listen or practise."], "Ordered activities • no mode picker", accent=True)
    card(956, 557, "04", "Show your thinking", ["Answer the actual task.", "Receive feedback on your gaps."], "Gaps → practise within this section")
    card(510, 557, "05", "Save the evidence", ["Record your response, evaluation,", "misconceptions and method."], "A save alone does not prove mastery")
    card(64, 557, "06", "Adapt what is next", ["After required methods complete,", "tailor the next eligible section."], "Objective + method mix + pacing")
    d.path("M468 338 H502")
    d.path("M914 338 H948")
    d.path("M1154 470 V549")
    d.path("M948 680 H914")
    d.path("M502 680 H468")

    d.path("M262 813 V853 H1384 V338 H1360", C["teal"], dashed=True, teal=True)
    d.box(576, 833, 634, 40, C["canvas"], radius=0)
    d.text(893, 860, "Evidence shapes the next section", 23, C["teal"], 600, "middle")

    d.box(64, 902, 1288, 66, C["white"], C["line"], 16)
    d.text(91, 944, "FOCUS BY DESIGN", 18, C["indigo"], 700)
    d.text(304, 944, "Current section visible · completed history available · future content hidden", 23, C["muted"])
    d.save("learning-loop.svg")


def system_architecture():
    d = Diagram(
        1440, 1180, "Lumap: native clients and shared learning architecture",
        "Native macOS and iPhone or iPad clients use a shared Swift domain. LumapStore "
        "controls the session and progression. LearningAgentService plans, generates, "
        "evaluates and adapts through validated contracts and LumapAIClient provider "
        "adapters. Public-topic research and selected private material excerpts follow "
        "separate input routes; document contents do not become public search queries. "
        "Configured model providers receive the chosen learning context. SwiftData, "
        "Keychain, validated caches, Kokoro narration and media export run on-device. "
        "Current personalization uses model decisions with local constraints; trained RL "
        "and camera-based AR are not deployed in this architecture.",
    )
    d.text(64, 68, "THE SYSTEM ARCHITECTURE", 18, C["indigo"], 700)
    d.text(64, 121, "Native experience. Shared learning intelligence.", 40, weight=650)
    d.text(64, 163, "Implemented MVP · model-driven adaptation with local progression constraints", 24, C["muted"])

    d.box(64, 209, 618, 95, C["white"], C["line"])
    d.text(91, 248, "macOS", 27, weight=650)
    d.text(91, 279, "SwiftUI + AppKit · studio, menu bar, Persona", 23, C["muted"])
    d.box(718, 209, 658, 95, C["white"], C["line"])
    d.text(745, 248, "iPhone & iPad", 27, weight=650)
    d.text(745, 279, "SwiftUI · responsive learning, media and Handoff", 23, C["muted"])
    d.path("M373 313 V336 H710 V361")
    d.path("M1047 313 V336 H746 V361")

    # Inputs and external boundaries are distinct from the shared domain.
    d.text(64, 361, "GROUNDED INPUTS", 18, C["muted"], 700)
    d.box(64, 381, 310, 197, C["white"], C["line"])
    d.text(88, 421, "Public research", 26, weight=650)
    d.lines(88, 459, ["DuckDuckGo + Wikipedia", "Readable public pages", "Up to 5 source excerpts"], 22, 32, C["muted"])
    d.text(88, 560, "Search query: topic only", 20, C["teal"], 600)
    d.box(64, 610, 310, 182, C["green"], C["line"])
    d.text(88, 650, "Selected materials", 26, weight=650)
    d.lines(88, 688, ["PDFKit + text extraction", "Chosen private excerpts", "No public document query"], 22, 32, C["muted"])

    d.box(424, 373, 610, 419, C["soft"], C["line"], 24)
    d.text(448, 411, "SHARED SWIFT DOMAIN", 18, C["indigo"], 700)
    d.box(448, 433, 562, 86, C["white"], radius=14)
    d.text(471, 466, "LumapStore", 26, weight=650)
    d.text(471, 498, "Session state · section gates · saved progress", 22, C["muted"])
    d.path("M729 526 V545")
    d.box(448, 552, 562, 93, C["white"], radius=14)
    d.text(471, 587, "LearningAgentService", 26, weight=650)
    d.text(471, 620, "Plan → generate → evaluate → adapt", 22, C["muted"])
    d.path("M729 652 V671")
    d.box(448, 678, 562, 89, C["white"], radius=14)
    d.text(471, 712, "Validated contracts + LumapAIClient", 25, weight=650)
    d.text(471, 744, "Source IDs · prerequisites · bounded requests", 22, C["muted"])
    d.path("M382 479 H402 V585 H440")
    d.path("M382 701 H414 V614 H440")

    d.text(1080, 361, "CONFIGURED ENDPOINT", 18, C["muted"], 700)
    d.box(1080, 381, 296, 411, C["white"], C["line"])
    d.text(1104, 425, "Model provider", 27, weight=650)
    d.lines(1104, 467, ["Remote service or", "compatible local host"], 23, 33, C["muted"])
    d.path("M1104 524 H1352", C["line"], arrow=False)
    d.lines(1104, 563, ["Responses", "Chat Completions", "Anthropic Messages"], 23, 34, C["muted"])
    d.text(1104, 694, "Receives selected context", 20, C["teal"], 600)
    d.lines(1104, 727, ["Goal, learner signals", "and chosen excerpts"], 21, 30, C["muted"])
    d.path("M1042 723 H1072")

    d.path("M729 801 V832")
    d.box(64, 840, 1312, 270, C["white"], C["line"], 24)
    d.text(88, 880, "ON-DEVICE SERVICES", 18, C["indigo"], 700)
    d.path("M472 907 V1079", C["line"], arrow=False)
    d.path("M920 907 V1079", C["line"], arrow=False)

    d.text(88, 932, "SwiftData + cache", 27, weight=650)
    d.lines(88, 973, ["Goals, answers and evaluations", "Materials, progress and rewards", "Section-scoped lesson cache"], 22, 34, C["muted"])
    d.text(88, 1085, "Handoff: explicit file transfer", 21, C["teal"], 600)

    d.text(496, 932, "Narration + exports", 27, weight=650)
    d.lines(496, 973, ["Kokoro INT8 + sherpa-onnx", "Full script → local speech → media", "AVFoundation + Office Open XML"], 22, 34, C["muted"])
    d.text(496, 1085, "MP4 · editable PPTX · teaching script", 21, C["teal"], 600)

    d.text(944, 932, "Keychain", 27, weight=650)
    d.lines(944, 973, ["Device-local provider credential", "Excluded from Handoff exports", "Voice weights installed separately"], 22, 34, C["muted"])
    d.text(944, 1085, "Private by explicit boundaries", 21, C["teal"], 600)

    d.text(64, 1152, "Architecture view: service responsibilities and data routes, not a complete call graph.", 20, C["muted"])
    d.save("system-architecture.svg")


def narration_coverage():
    examples = OUT.parent / "examples"
    metadata = json.loads((examples / "photosynthesis-verification.json").read_text(encoding="utf-8"))
    script = (examples / "photosynthesis-teaching-script.txt").read_text(encoding="utf-8")
    titles = re.findall(r"^\d+\. (.+)$", script, re.MULTILINE)
    counts = metadata["narrationWordsPerSlide"]
    if len(titles) != len(counts) or len(counts) != metadata["slideCount"]:
        raise ValueError("The verification metadata and teaching script must agree on chapter count")
    total_words = sum(counts)
    d = Diagram(
        1440, 1000, "Narration coverage in the verified photosynthesis lesson",
        "Horizontal bars start at zero and show narration word counts for each chapter "
        "of one generated lesson. " + "; ".join(f"{title}: {count} words" for title, count in zip(titles, counts)) +
        f". The export contains {total_words} narration words, {metadata['slideCount']} chapters "
        f"and {metadata['quizCount']} quizzes, lasting {metadata['durationSeconds']:.2f} seconds. "
        "This is a single verified export, not an efficacy study or performance benchmark.",
    )
    d.text(64, 68, "A VERIFIED MEDIA EXAMPLE", 18, C["indigo"], 700)
    d.text(64, 121, "A complete script for every chapter", 42, weight=650)
    d.text(64, 163, "Photosynthesis: Building a Plant from Air and Water", 25, C["muted"])

    stats = [
        (str(total_words), "narration words"),
        (str(metadata["slideCount"]), "complete chapters"),
        (str(metadata["quizCount"]), "retrieval quizzes"),
        (f"{metadata['durationSeconds']:.2f} s", "exported video duration"),
    ]
    for index, (value, label) in enumerate(stats):
        x = 64 + index * 334
        d.box(x, 209, 310, 100, C["white"], C["line"], 18)
        d.text(x + 23, 252, value, 31, C["indigo"], 650)
        d.text(x + 23, 284, label, 22, C["muted"])

    start, width = 710, 576
    maximum = int(math.ceil(max(counts) / 30) * 30)
    for tick in range(0, maximum + 1, 30):
        x = start + width * tick / maximum
        d.path(f"M{x:g} 350 V840", C["line"], arrow=False)
        d.text(x, 877, str(tick), 22, C["muted"], anchor="middle")
    d.text(start + width / 2, 915, "Narration words per chapter · axis starts at zero", 22, C["muted"], anchor="middle")
    for index, (title, count) in enumerate(zip(titles, counts)):
        y = 394 + index * 80
        d.text(88, y + 5, f"{index + 1:02d}", 21, C["indigo"], 650)
        wrapped = textwrap.wrap(title, width=43)
        d.lines(137, y - (12 if len(wrapped) > 1 else 0), wrapped, 23, 30, C["ink"])
        bar_width = width * count / maximum
        d.box(start, y - 20, bar_width, 31, C["indigo"], radius=5)
        d.text(start + bar_width + 16, y + 4, str(count), 23, C["ink"], 600)

    date = metadata["generatedAt"].split("T", 1)[0]
    d.text(64, 972, f"Single verified export · {date} · observed media coverage, not a learning-efficacy benchmark.", 21, C["muted"])
    d.save("narration-coverage.svg")


if __name__ == "__main__":
    learning_loop()
    system_architecture()
    narration_coverage()
    print(f"Wrote learning-loop.svg, system-architecture.svg and narration-coverage.svg to {OUT}")
