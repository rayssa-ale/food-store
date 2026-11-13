"""Genera el PDF del informe técnico de la segunda entrega (U4-U8).

Uso:
    python SEGUNDA_ENTREGA/generar_informe_segunda_entrega.py

Lee `informe_tecnico_segunda_entrega.md` y escribe
`informe_tecnico_segunda_entrega.pdf` en la misma carpeta.
"""

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
    XPreformatted,
)

HERE = Path(__file__).resolve().parent
MD = HERE / "informe_tecnico_segunda_entrega.md"
PDF = HERE / "informe_tecnico_segunda_entrega.pdf"

styles = getSampleStyleSheet()
body = ParagraphStyle(
    "BodySE", parent=styles["BodyText"], fontName="Helvetica", fontSize=9.0,
    leading=11.6, alignment=TA_LEFT, spaceAfter=3.5,
)
h1 = ParagraphStyle(
    "H1SE", parent=styles["Heading1"], fontName="Helvetica-Bold", fontSize=17,
    leading=20, spaceAfter=6, textColor=colors.HexColor("#17324d"),
)
h2 = ParagraphStyle(
    "H2SE", parent=styles["Heading2"], fontName="Helvetica-Bold", fontSize=12,
    leading=15, spaceBefore=9, spaceAfter=3.5, textColor=colors.HexColor("#17324d"),
)
h3 = ParagraphStyle(
    "H3SE", parent=styles["Heading3"], fontName="Helvetica-Bold", fontSize=10,
    leading=12.6, spaceBefore=5, spaceAfter=2,
)
cell = ParagraphStyle(
    "CellSE", parent=body, fontSize=7.4, leading=9.0, spaceAfter=0,
)
cell_b = ParagraphStyle(
    "CellBSE", parent=cell, fontName="Helvetica-Bold",
)
code = ParagraphStyle(
    "CodeSE", parent=body, fontName="Courier", fontSize=7.4, leading=9.0,
    leftIndent=4, spaceBefore=2, spaceAfter=5,
    backColor=colors.HexColor("#f4f6f8"), borderPadding=3,
)


def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"`(.+?)`", r'<font name="Courier" size="7.9">\1</font>', text)
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
    if n == 3:
        return [5.4 * cm, 6.6 * cm, 6.0 * cm]
    if n == 4:
        return [2.9 * cm, 5.4 * cm, 5.4 * cm, 4.3 * cm]
    if n == 5:
        return [0.9 * cm, 3.6 * cm, 6.3 * cm, 4.2 * cm, 3.0 * cm]
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
        if not line.strip() or line.strip() == "---":
            i += 1
            continue
        if line.startswith("```"):
            i += 1
            block = []
            while i < len(lines) and not lines[i].startswith("```"):
                block.append(lines[i].rstrip("\n"))
                i += 1
            i += 1  # cierra el fence
            story.append(XPreformatted("\n".join(block), code))
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
            story.append(Paragraph("&bull; " + inline(text), body))
            continue
        # párrafo: junta líneas hasta un bloque
        parts = [line.strip()]
        i += 1
        while i < len(lines):
            nxt = lines[i]
            if (not nxt.strip() or nxt.startswith("#") or nxt.startswith("|")
                    or nxt.startswith("- ") or nxt.startswith("```")
                    or nxt.strip() == "---"):
                break
            parts.append(nxt.strip())
            i += 1
        story.append(Paragraph(inline(" ".join(parts)), body))
    return story


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 7.2)
    canvas.setFillColor(colors.HexColor("#5b6f82"))
    canvas.drawString(
        1.35 * cm, 0.7 * cm,
        "Food Store - Segunda entrega (U4-U8) - Equipo G - Base de Datos II",
    )
    canvas.drawRightString(
        A4[0] - 1.35 * cm, 0.7 * cm, f"pág. {doc.page}",
    )
    canvas.restoreState()


def main():
    text = MD.read_text(encoding="utf-8")
    doc = SimpleDocTemplate(
        str(PDF), pagesize=A4,
        leftMargin=1.35 * cm, rightMargin=1.35 * cm,
        topMargin=1.25 * cm, bottomMargin=1.15 * cm,
        title="Food Store - Segunda entrega (U4-U8)",
        author="Equipo G - Base de Datos II",
    )
    doc.build(parse(text), onFirstPage=footer, onLaterPages=footer)
    print(f"PDF generado: {PDF}")


if __name__ == "__main__":
    main()
