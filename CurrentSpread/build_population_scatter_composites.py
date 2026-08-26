from __future__ import annotations

import csv
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(r"C:\EM\CurrentSpread")
RESULTS = ROOT / "UnifiedBestChannelReanalysis_MaxOD_20260820"
OUTPUT_DIR = RESULTS / "figures" / "population_scatter_panels"

METHODS = [
    ("00_OriginalQuick_StimChannel", "00_OriginalQuick_StimChannel"),
    ("01_StimTask_NoStim", "01_StimTask_NoStim"),
    ("02_BestQuick_AllChannels", "02_BestQuick_AllChannels"),
    ("03_BestQuick_Within200um", "03_BestQuick_Within200um"),
]

CUE_COLORS = {
    "Dominant": "#F2A900",
    "Combined": "#111111",
    "Stereo": "#D900D9",
    "NonDominant": "#55BDD0",
}


def figure_path(folder: str, prefix: str, area: str, unit_type: str) -> Path:
    return RESULTS / folder / area / f"{prefix}_{area}_Population_{unit_type}.png"


def load_session_counts(folder: str, area: str, unit_type: str) -> dict[str, int]:
    path = RESULTS / folder / area / "PopulationConditionSummary.csv"
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    counts = {
        row["Condition"]: int(round(float(row["NUnits"])))
        for row in rows
        if row["UnitType"] == unit_type
    }
    expected = set(CUE_COLORS)
    if set(counts) != expected:
        raise ValueError(
            f"Cue session counts are incomplete for {folder}/{area}/{unit_type}: {counts}"
        )
    return counts


def load_font(size: int, bold: bool = False):
    filename = "calibrib.ttf" if bold else "calibri.ttf"
    path = Path(r"C:\Windows\Fonts") / filename
    if path.is_file():
        return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default(size=size)


def add_session_count_box(image: Image.Image, counts: dict[str, int]) -> Image.Image:
    annotated = image.copy()
    draw = ImageDraw.Draw(annotated)
    x0, y0, x1, y1 = 1345, 345, 1707, 660
    draw.rounded_rectangle(
        (x0, y0, x1, y1),
        radius=8,
        fill="#F5F7FA",
        outline="#687587",
        width=3,
    )
    draw.text(
        (x0 + 18, y0 + 12),
        "Sessions (N)",
        font=load_font(46, bold=True),
        fill="#163A5F",
    )
    y = y0 + 68
    for cue in ("Dominant", "Combined", "Stereo", "NonDominant"):
        draw.text(
            (x0 + 18, y),
            f"{cue}  {counts[cue]}",
            font=load_font(44),
            fill=CUE_COLORS[cue],
        )
        y += 50
    return annotated


def build_composite(folder: str, prefix: str) -> Path:
    panels = [
        ("MT", "2D", figure_path(folder, prefix, "MT", "2D")),
        ("MT", "3D", figure_path(folder, prefix, "MT", "3D")),
        ("FST", "2D", figure_path(folder, prefix, "FST", "2D")),
        ("FST", "3D", figure_path(folder, prefix, "FST", "3D")),
    ]
    missing = [str(path) for _, _, path in panels if not path.is_file()]
    if missing:
        raise FileNotFoundError("Missing source population plots:\n" + "\n".join(missing))

    images = [
        add_session_count_box(
            Image.open(path).convert("RGB"),
            load_session_counts(folder, area, unit_type),
        )
        for area, unit_type, path in panels
    ]
    tile_width = max(image.width for image in images)
    tile_height = max(image.height for image in images)
    gutter = 28
    canvas = Image.new(
        "RGB",
        (tile_width * 2 + gutter * 3, tile_height * 2 + gutter * 3),
        "white",
    )
    draw = ImageDraw.Draw(canvas)
    for index, image in enumerate(images):
        column = index % 2
        row = index // 2
        x = gutter + column * (tile_width + gutter)
        y = gutter + row * (tile_height + gutter)
        canvas.paste(image, (x, y))
        draw.rectangle(
            (x - 1, y - 1, x + image.width, y + image.height),
            outline="#D4DAE2",
            width=2,
        )

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output = OUTPUT_DIR / f"{folder}_Population_FourPanel.png"
    canvas.save(output, dpi=(220, 220), optimize=True)
    return output


def main() -> None:
    for folder, prefix in METHODS:
        print(build_composite(folder, prefix))


if __name__ == "__main__":
    main()
