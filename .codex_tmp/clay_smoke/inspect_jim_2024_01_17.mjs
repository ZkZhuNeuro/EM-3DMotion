import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "P:/Jim/NeuroData/RecordingRecord_Stimulation_final.xlsx";
const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(inputPath));
const sheet = workbook.worksheets.getItemAt(0);
const table = sheet.getUsedRange(true).values;
const headers = table[0].map((v) => String(v ?? "").trim());
const normalized = headers.map((v) => v.toLowerCase().replaceAll(/[^a-z0-9]/g, ""));
const col = (name) => {
  const i = normalized.indexOf(name.toLowerCase().replaceAll(/[^a-z0-9]/g, ""));
  if (i < 0) throw new Error(`Missing column ${name}`);
  return i;
};
const isoDate = (value) => {
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  if (typeof value === "number") return new Date(Date.UTC(1899, 11, 30) + value * 86400000).toISOString().slice(0, 10);
  const parsed = new Date(String(value ?? ""));
  return Number.isNaN(parsed.valueOf()) ? null : parsed.toISOString().slice(0, 10);
};
const vector = (value) => String(value ?? "").match(/[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?/g)?.map(Number) ?? [];

const target = "2023-01-17";
const matches = [];
const nearby = [];
const workbookQualifiedOffsets = [];
for (let i = 1; i < table.length; i += 1) {
  const rawDate = table[i][col("Date")];
  const normalizedDate = isoDate(rawDate);
  const rowRoi = String(table[i][col("ROI")] ?? "").trim().toUpperCase();
  const rowMuaStim = String(table[i][col("MUAStim")] ?? "").trim().toUpperCase();
  const rowOffset = vector(table[i][col("Offset")]);
  if (normalizedDate && ["MT", "FST"].includes(rowRoi) && rowMuaStim === "Y" && rowOffset.length === 3) {
    workbookQualifiedOffsets.push({ workbookRow: i + 1, date: normalizedDate, roi: rowRoi, offset: rowOffset });
  }
  if ((normalizedDate?.startsWith("2023-01")) || String(rawDate ?? "").includes("2023")) {
    nearby.push({ workbookRow: i + 1, rawDate, normalizedDate, roi: table[i][col("ROI")], offset: table[i][col("Offset")] });
  }
  if (normalizedDate !== target) continue;
  const hole = vector(table[i][col("Hole")]);
  const offset = vector(table[i][col("Offset")]);
  const baseApVoxel = 68 - ((29 - hole[1]) * 0.8) * 2;
  const adjustedApVoxel = baseApVoxel + 2 * offset[1];
  const workbookRow = i + 1;
  const exact = await workbook.inspect({
    kind: "table",
    sheetId: sheet.name,
    range: `A${workbookRow}:Z${workbookRow}`,
    include: "values,formulas",
    tableMaxRows: 2,
    tableMaxCols: 26,
    maxChars: 5000,
  });
  matches.push({
    workbookRow,
    date: target,
    roi: String(table[i][col("ROI")] ?? "").trim(),
    muaStim: String(table[i][col("MUAStim")] ?? "").trim(),
    hole,
    offset,
    baseApVoxel,
    adjustedApVoxel,
    adjustedMriSliceIndex: Math.round(adjustedApVoxel) + 1,
    exactRowInspection: exact.ndjson,
  });
}

const previewDir = "C:/Users/zzhu329/Documents/GitHub/EM-3DMotion/.codex_tmp/clay_smoke/previews";
await fs.mkdir(previewDir, { recursive: true });
if (matches.length) {
  const row = matches[0].workbookRow;
  const preview = await workbook.render({ sheetName: sheet.name, range: `A${row}:Z${row}`, scale: 2, format: "png" });
  await fs.writeFile(`${previewDir}/jim_2023_01_17_row.png`, new Uint8Array(await preview.arrayBuffer()));
}
const search = await workbook.inspect({
  kind: "match",
  searchTerm: "1/17/2023|01/17/2023|2023-01-17|1/17/23|20230117|230117|011723",
  options: { useRegex: true, maxResults: 50 },
  maxChars: 5000,
});
const nearbyRowNumbers = nearby.map((row) => row.workbookRow);
const nearbyStart = Math.max(2, Math.min(...nearbyRowNumbers) - 1);
const nearbyEnd = Math.max(...nearbyRowNumbers) + 1;
const nearbyRows = await workbook.inspect({
  kind: "table",
  sheetId: sheet.name,
  range: `A${nearbyStart}:Z${nearbyEnd}`,
  include: "values,formulas",
  tableMaxRows: 10,
  tableMaxCols: 26,
  maxChars: 12000,
});
const nonzeroYOffsets = workbookQualifiedOffsets.filter((row) => Math.abs(row.offset[1]) > 1e-12);
console.log(JSON.stringify({
  sheetName: sheet.name,
  workbookQualifiedCount: workbookQualifiedOffsets.length,
  nonzeroYOffsetCount: nonzeroYOffsets.length,
  nonzeroYOffsets,
  matches,
  nearby,
  search: search.ndjson,
  nearbyRows: nearbyRows.ndjson,
}, null, 2));
