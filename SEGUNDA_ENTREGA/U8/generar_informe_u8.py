import html
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import (
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

ROOT = Path(__file__).resolve().parents[1]
MD = ROOT / "docs" / "informe_u8.md"
PDF = ROOT / "docs" / "informe.pdf"

styles = getSampleStyleSheet()
body = ParagraphStyle(
    "Body8", parent=styles["BodyText"], fontName="Helvetica", fontSize=8.8,
    leading=11.0, alignment=TA_LEFT, spaceAfter=3,
)
h1 = ParagraphStyle(
    "H1_8", parent=styles["Heading1"], fontName="Helvetica-Bold", fontSize=16,
    leading=19, spaceAfter=5, textColor=colors.HexColor("#17324d"),
)
h2 = ParagraphStyle(
    "H2_8", parent=styles["Heading2"], fontName="Helvetica-Bold", fontSize=11.5,
    leading=14, spaceBefore=7, spaceAfter=3, textColor=colors.HexColor("#17324d"),
)
h3 = ParagraphStyle(
    "H3_8", parent=styles["Heading3"], fontName="Helvetica-Bold", fontSize=9.5,
    leading=12, spaceBefore=4, spaceAfter=2,
)
cell = ParagraphStyle(
    "Cell8", parent=body, fontSize=7.2, leading=8.6, spaceAfter=0,
)
cell_b = ParagraphStyle(
    "CellB8", parent=cell, fontName="Helvetica-Bold",
)


def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"\*(.+?)\*", r"<i>\1</i>", text)
    text = re.sub(
        r"`(.+?)`",
        r'<font name="Courier" size="7.4">\1</font>',
        text,
    )
    return text


def split_table_row(line):
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|"):
        line = line[:-1]
    return [c.strip() for c in line.split("|")]


def table_widths(header):
    n = len(header)
    if n == 2:
        return [8.4 * cm, 9.6 * cm]
    if n == 4 and header and header[0].lower() == "caso":
        return [1.6 * cm, 5.4 * cm, 4.9 * cm, 6.1 * cm]
    if n == 3 and header and header[0].lower() == "motor":
        return [3.5 * cm, 7.3 * cm, 7.2 * cm]
    if n == 3 and header and header[0].lower().startswith("hallazgo"):
        return [5.0 * cm, 3.0 * cm, 10.0 * cm]
    return [18.0 * cm / n] * n


def make_table(rows):
    header = rows[0]
    data = []
    for r, row in enumerate(rows):
        style = cell_b if r == 0 else cell
        data.append([Paragraph(inline(c), style) for c in row])
    t = Table(data, colWidths=table_widths(header), repeatRows=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dbe7f3")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#17324d")),
        ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#8aa0b5")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 2.5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 2.5),
        ("TOPPADDING", (0, 0), (-1, -1), 2.0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 2.0),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f7fafc")]),
    ]))
    return t


def parse(md_text):
    lines = md_text.splitlines()
    story = []
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        if not line.strip():
            i += 1
            continue
        if line.startswith("# "):
            story.append(Paragraph(inline(line[2:].strip()), h1))
            i += 1
            continue
        if line.startswith("## "):
            story.append(Paragraph(inline(line[3:].strip()), h2))
            i += 1
            continue
        if line.startswith("### "):
            story.append(Paragraph(inline(line[4:].strip()), h3))
            i += 1
            continue
        if line.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                raw = lines[i].strip()
                if not re.match(r"^\|[\s:|\-]+\|?$", raw):
                    rows.append(split_table_row(raw))
                i += 1
            if rows:
                story.append(make_table(rows))
                story.append(Spacer(1, 3))
            continue
        if line.startswith("- "):
            text = line[2:].strip()
            i += 1
            while i < len(lines) and lines[i].startswith("  ") and lines[i].strip():
                text += " " + lines[i].strip()
                i += 1
            story.append(Paragraph("- " + inline(text), body))
            continue
        # parrafo: junta lineas hasta un bloque
        parts = [line.strip()]
        i += 1
        while i < len(lines):
            nxt = lines[i]
            if not nxt.strip() or nxt.startswith("#") or nxt.startswith("|") or nxt.startswith("- "):
                break
            parts.append(nxt.strip())
            i += 1
        story.append(Paragraph(inline(" ".join(parts)), body))
    return story


def main():
    text = MD.read_text(encoding="utf-8")
    doc = SimpleDocTemplate(
        str(PDF), pagesize=A4,
        leftMargin=1.35 * cm, rightMargin=1.35 * cm,
        topMargin=1.25 * cm, bottomMargin=1.15 * cm,
        title="Food Store - TP8 - Unidad 8",
        author="Equipo G - Base de Datos II",
    )
    doc.build(parse(text))
    print(f"PDF generado: {PDF}")


if __name__ == "__main__":
    main()
