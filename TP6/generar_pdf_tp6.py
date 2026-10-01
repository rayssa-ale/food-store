#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
FOOD STORE - Unidad 4 . TP6 . Generador del PDF del informe.

Convierte informe_tp6.md en TP6_Food_Store.pdf con reportlab,
respetando encabezados, listas, tablas y bloques de codigo
monoespaciado. No depende de Word ni de pandoc.

Uso:
    python TP6/generar_pdf_tp6.py
"""

import os
import re
import sys

from reportlab.lib import colors
from reportlab.lib.enums import TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import (
    PageBreak,
    Paragraph,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

BASE = os.path.dirname(os.path.abspath(__file__))
MD = os.path.join(BASE, "informe_tp6.md")
PDF = os.path.join(BASE, "TP6_Food_Store.pdf")

styles = getSampleStyleSheet()
S = {
    "h1": ParagraphStyle("h1", parent=styles["Heading1"], fontSize=17, spaceAfter=10,
                         spaceBefore=4, textColor=colors.HexColor("#10243e")),
    "h2": ParagraphStyle("h2", parent=styles["Heading2"], fontSize=13.5, spaceAfter=7,
                         spaceBefore=14, textColor=colors.HexColor("#1c3f66")),
    "h3": ParagraphStyle("h3", parent=styles["Heading3"], fontSize=11.5, spaceAfter=5,
                         spaceBefore=10, textColor=colors.HexColor("#2c5c8f")),
    "p": ParagraphStyle("p", parent=styles["BodyText"], fontSize=9.5, leading=13.2,
                        alignment=TA_JUSTIFY, spaceAfter=5),
    "li": ParagraphStyle("li", parent=styles["BodyText"], fontSize=9.5, leading=13.2,
                         alignment=TA_JUSTIFY, leftIndent=14, bulletIndent=4, spaceAfter=3),
    "code": ParagraphStyle("code", parent=styles["Code"], fontName="Courier",
                           fontSize=7.4, leading=8.9,
                           backColor=colors.HexColor("#f3f4f6"),
                           borderPadding=4, spaceBefore=4, spaceAfter=8),
    "cell": ParagraphStyle("cell", parent=styles["BodyText"], fontSize=8.2, leading=10.4),
    "cellb": ParagraphStyle("cellb", parent=styles["BodyText"], fontSize=8.2,
                            leading=10.4, fontName="Helvetica-Bold"),
}


def inline(t):
    """resalta **negrita** y `codigo` en el texto markdown."""
    t = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", t)
    t = re.sub(r"`(.+?)`", r"<font face='Courier' size='8.6'>\1</font>", t)
    return t


def es_sep(fila):
    return all(re.fullmatch(r":?-{2,}:?", c) for c in fila)


def filas_tabla(linea):
    return [c.strip() for c in linea.strip().strip("|").split("|")]


def construir_flujos(md):
    with open(md, encoding="utf-8") as fh:
        lineas = fh.read().splitlines()

    flujos, buf_tabla = [], []
    en_codigo, cod = False, []

    def cerrar_tabla():
        if not buf_tabla:
            return
        filas = [f for f in buf_tabla if not es_sep(f)]
        n = len(filas[0])
        filas = [f + [""] * (n - len(f)) for f in filas]
        datos = [[Paragraph(inline(c), S["cellb"] if i == 0 else S["cell"])
                  for c in f] for i, f in enumerate(filas)]
        anchos = [A4[0] - 3.4 * cm] * n
        t = Table(datos, colWidths=anchos, repeatRows=1)
        t.setStyle(TableStyle([
            ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#8898a8")),
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dce6f1")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("LEFTPADDING", (0, 0), (-1, -1), 4),
            ("RIGHTPADDING", (0, 0), (-1, -1), 4),
            ("TOPPADDING", (0, 0), (-1, -1), 3),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ]))
        flujos.extend([t, Spacer(1, 8)])
        buf_tabla.clear()

    i = 0
    while i < len(lineas):
        l = lineas[i]

        if l.startswith("```"):
            if en_codigo:
                flujos.append(Preformatted("\n".join(cod), S["code"]))
                cod, en_codigo = [], False
            else:
                cerrar_tabla()
                en_codigo = True
            i += 1
            continue
        if en_codigo:
            cod.append(l)
            i += 1
            continue

        if re.match(r"^\s*\|.*\|\s*$", l):
            buf_tabla.append(filas_tabla(l))
            i += 1
            continue
        cerrar_tabla()

        if not l.strip():
            i += 1
            continue

        if m := re.match(r"^(#{1,6})\s+(.*)$", l):
            lvl = min(len(m.group(1)), 3)
            flujos.append(Paragraph(inline(m.group(2)), S[f"h{lvl}"]))
        elif m := re.match(r"^\s*[-*]\s+(.*)$", l):
            flujos.append(Paragraph(inline(m.group(1)), S["li"], bulletText="\u2022"))
        elif m := re.match(r"^\s*\d+\.\s+(.*)$", l):
            n = re.match(r"^\s*(\d+)\.", l).group(1)
            flujos.append(Paragraph(inline(m.group(1)), S["li"], bulletText=f"{n}."))
        elif l.strip() == "---":
            flujos.append(Spacer(1, 4))
        else:
            # une renglones sueltos del mismo parrafo
            par = [l.strip()]
            j = i + 1
            while j < len(lineas) and lineas[j].strip() and not re.match(
                    r"^\s*(#{1,6}\s|[-*]\s|\d+\.\s|\||```)", lineas[j]):
                par.append(lineas[j].strip())
                j += 1
            flujos.append(Paragraph(inline(" ".join(par)), S["p"]))
            i = j - 1
        i += 1

    if en_codigo and cod:
        flujos.append(Preformatted("\n".join(cod), S["code"]))
    cerrar_tabla()
    return flujos


def pie(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 7.5)
    canvas.setFillColor(colors.HexColor("#667788"))
    canvas.drawString(1.7 * cm, 1.1 * cm,
                      "Food Store - Base de Datos II (UTN) - Unidad 4: FNBC y "
                      "desnormalizacion controlada")
    canvas.drawRightString(A4[0] - 1.7 * cm, 1.1 * cm, "pagina %d" % doc.page)
    canvas.setStrokeColor(colors.HexColor("#b0bcc8"))
    canvas.setLineWidth(0.4)
    canvas.line(1.7 * cm, 1.5 * cm, A4[0] - 1.7 * cm, 1.5 * cm)
    canvas.restoreState()


def main():
    if not os.path.exists(MD):
        sys.exit("No existe el informe: %s" % MD)
    doc = SimpleDocTemplate(
        PDF, pagesize=A4,
        leftMargin=1.7 * cm, rightMargin=1.7 * cm,
        topMargin=1.8 * cm, bottomMargin=2.0 * cm,
        title="Food Store - Unidad 4: FNBC y desnormalizacion controlada",
        author="Equipo G",
    )
    doc.build(construir_flujos(MD), onFirstPage=pie, onLaterPages=pie)
    print("PDF generado: %s (%.1f KB)" % (PDF, os.path.getsize(PDF) / 1024))


if __name__ == "__main__":
    main()