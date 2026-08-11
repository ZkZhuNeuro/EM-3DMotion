import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "P:/Jim/NeuroData/RecordingRecord_Stimulation_final.xlsx";
const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(inputPath));
const sheet = workbook.worksheets.getItemAt(0);
const table = sheet.getUsedRange(true).values;
const headers = table[0].map((value) => String(value ?? "").trim());
const normalizedHeaders = headers.map((name) => name.toLowerCase().replaceAll(/[^a-z0-9]/g, ""));
const col = (name) => {
  const index = normalizedHeaders.indexOf(name.toLowerCase().replaceAll(/[^a-z0-9]/g, ""));
  if (index < 0) throw new Error(`Missing column: ${name}`);
  return index;
};

function excelDateToIso(value) {
  if (value instanceof Date && !Number.isNaN(value.valueOf())) return value.toISOString().slice(0, 10);
  if (typeof value === "number" && Number.isFinite(value)) {
    return new Date(Date.UTC(1899, 11, 30) + value * 86400000).toISOString().slice(0, 10);
  }
  const parsed = new Date(String(value ?? "").trim());
  return Number.isNaN(parsed.valueOf()) ? null : parsed.toISOString().slice(0, 10);
}

function parseVector(value) {
  return String(value ?? "")
    .replaceAll(/[\[\]\s]/g, "")
    .split(",")
    .filter(Boolean)
    .map(Number);
}

const mtRows = [];
for (let i = 1; i < table.length; i += 1) {
  const row = table[i];
  if (String(row[col("ROI")] ?? "").trim().toUpperCase() !== "MT") continue;
  const hole = parseVector(row[col("Hole")]);
  const offset = parseVector(row[col("Offset")]);
  if (hole.length !== 2 || offset.length !== 3) continue;
  const apVoxel = 68 - ((29 - hole[1]) * 0.8) * 2 + 2 * offset[1];
  mtRows.push({
    workbookRow: i + 1,
    date: excelDateToIso(row[col("Date")]),
    roi: "MT",
    hole,
    offset,
    apVoxel,
    mriSliceIndex: Math.round(apVoxel) + 1,
  });
}
mtRows.sort((a, b) => a.apVoxel - b.apVoxel || a.date.localeCompare(b.date));
const minimum = mtRows[0]?.apVoxel;
const minimumRows = mtRows.filter((row) => Math.abs(row.apVoxel - minimum) < 1e-12);
const largestGridY = Math.max(...mtRows.map((row) => row.hole[1]));
const largestGridYRows = mtRows.filter((row) => row.hole[1] === largestGridY);
const sourceRows = [];
for (const row of largestGridYRows) {
  const inspected = await workbook.inspect({
    kind: "table",
    sheetId: sheet.name,
    range: `A${row.workbookRow}:Z${row.workbookRow}`,
    include: "values,formulas",
    tableMaxRows: 2,
    tableMaxCols: 26,
    maxChars: 5000,
  });
  sourceRows.push(inspected.ndjson);
}

console.log(JSON.stringify({
  sheetName: sheet.name,
  mtWorkbookCount: mtRows.length,
  minimumApVoxel: minimum,
  minimumRows,
  largestGridY,
  largestGridYRows,
  nextRows: mtRows.slice(0, 10),
  sourceRows,
}, null, 2));
