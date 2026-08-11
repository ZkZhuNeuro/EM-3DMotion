import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "P:/Jim/NeuroData/RecordingRecord_Stimulation_final.xlsx";
const input = await FileBlob.load(inputPath);
const workbook = await SpreadsheetFile.importXlsx(input);
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
  const text = String(value ?? "").trim();
  if (!text) return null;
  const parsed = new Date(text);
  return Number.isNaN(parsed.valueOf()) ? null : parsed.toISOString().slice(0, 10);
}

function parseVector(value) {
  if (Array.isArray(value)) return value.map(Number);
  return String(value ?? "")
    .replaceAll(/[\[\]\s]/g, "")
    .split(",")
    .filter(Boolean)
    .map(Number);
}

const included = [];
const excludedCounts = new Map();
for (let i = 1; i < table.length; i += 1) {
  const row = table[i];
  const date = excelDateToIso(row[col("Date")]);
  const roi = String(row[col("ROI")] ?? "").trim().toUpperCase();
  const muaStim = String(row[col("MUAStim")] ?? "").trim().toUpperCase();
  const reasons = [];
  if (!date) reasons.push("missing date");
  if (muaStim !== "Y") reasons.push(`MUAStim=${muaStim || "blank"}`);
  if (!new Set(["MT", "FST"]).has(roi)) reasons.push(`ROI=${roi || "blank"}`);
  if (reasons.length) {
    for (const reason of reasons) excludedCounts.set(reason, (excludedCounts.get(reason) ?? 0) + 1);
    continue;
  }
  const hole = parseVector(row[col("Hole")]);
  const offset = parseVector(row[col("Offset")]);
  included.push({
    workbookRow: i + 1,
    date,
    hole,
    guideTubeMm: Number(row[col("Guide Tube")]),
    depthMm: Number(row[col("Depth")]),
    offset,
    roi,
    muaStim,
    stimElec: Number(row[col("StimElec")]),
  });
}

const roiCounts = { MT: 0, FST: 0 };
const rowCoverage = {};
const columnCoverage = {};
const offsetCounts = {};
for (const row of included) {
  roiCounts[row.roi] += 1;
  const [x, y] = row.hole;
  rowCoverage[y] ??= { MT: 0, FST: 0, total: 0 };
  rowCoverage[y][row.roi] += 1;
  rowCoverage[y].total += 1;
  columnCoverage[x] ??= { MT: 0, FST: 0, total: 0 };
  columnCoverage[x][row.roi] += 1;
  columnCoverage[x].total += 1;
  const offsetKey = `[${row.offset.join(",")}]`;
  offsetCounts[offsetKey] = (offsetCounts[offsetKey] ?? 0) + 1;
}

const fstRows = included
  .filter((row) => row.roi === "FST")
  .map((row) => ({
    ...row,
    adjustedZMm: row.guideTubeMm + row.depthMm + row.offset[2],
    plottedYPixel: 48 + 2 * (row.guideTubeMm + row.depthMm + row.offset[2]),
  }))
  .sort((a, b) => a.adjustedZMm - b.adjustedZMm || a.date.localeCompare(b.date));

const origin = [127, 208, 68];
const coronalRows = included.map((row) => {
  const apVoxel = origin[2] - ((29 - row.hole[1]) * 0.8) * 2 + 2 * row.offset[1];
  return { ...row, apVoxel, roundedApVoxel: Math.round(apVoxel), mriSliceIndex: Math.round(apVoxel) + 1 };
});
const occupiedApVoxels = [...new Set(coronalRows.map((row) => row.roundedApVoxel))].sort((a, b) => a - b);
const allApVoxels = Array.from(
  { length: Math.max(...occupiedApVoxels) - Math.min(...occupiedApVoxels) + 1 },
  (_, i) => Math.min(...occupiedApVoxels) + i,
);
const hiddenApVoxels = allApVoxels.filter((voxel) => !occupiedApVoxels.includes(voxel));

const sagittalRows = included.map((row) => {
  const [x, y] = row.hole;
  const edgeOffset = Math.abs(y % 2) === 1 ? 1.4 : 1.8;
  const plottedMlVoxel = x > 0
    ? origin[0] - (((x - 1) * 0.8) + edgeOffset) * 2 + 2 * row.offset[0]
    : origin[0] + (((Math.abs(x) - 1) * 0.8) + edgeOffset) * 2 + 2 * row.offset[0];
  return {
    ...row,
    plottedMlVoxel,
    roundedPlottedMlVoxel: Math.round(plottedMlVoxel),
    mriMlVoxel: 255 - Math.round(plottedMlVoxel),
  };
});
const occupiedMlVoxels = [...new Set(sagittalRows.map((row) => row.mriMlVoxel))].sort((a, b) => a - b);
const allMlVoxels = Array.from(
  { length: Math.max(...occupiedMlVoxels) - Math.min(...occupiedMlVoxels) + 1 },
  (_, i) => Math.min(...occupiedMlVoxels) + i,
);
const hiddenMlVoxels = allMlVoxels.filter((voxel) => !occupiedMlVoxels.includes(voxel));

const lowestFst = fstRows.filter((row) => row.adjustedZMm === fstRows[0]?.adjustedZMm);
const expectedSessionFiles = new Set(included.map((row) =>
  `Jim_${row.roi}_${row.date}_Hole_${row.hole[0]}-${row.hole[1]}.png`));
const sessionOutputDir = "C:/EM/RecordingLocationPlots/Jim";
const actualSessionFiles = new Set((await fs.readdir(sessionOutputDir))
  .filter((name) => /^Jim_(MT|FST)_.*_Hole_.*\.png$/i.test(name)));
const missingSessionFiles = [...expectedSessionFiles].filter((name) => !actualSessionFiles.has(name)).sort();
const unexpectedSessionFiles = [...actualSessionFiles].filter((name) => !expectedSessionFiles.has(name)).sort();
const sourceRows = [];
for (const row of lowestFst) {
  const source = await workbook.inspect({
    kind: "table",
    sheetId: sheet.name,
    range: `A${row.workbookRow}:Z${row.workbookRow}`,
    include: "values,formulas",
    tableMaxRows: 2,
    tableMaxCols: 26,
    maxChars: 5000,
  });
  sourceRows.push(source.ndjson);
}

const previewDir = "C:/Users/zzhu329/Documents/GitHub/EM-3DMotion/.codex_tmp/clay_smoke/previews";
await fs.mkdir(previewDir, { recursive: true });
const preview = await workbook.render({ sheetName: sheet.name, autoCrop: "all", scale: 1, format: "png" });
await fs.writeFile(`${previewDir}/Jim_recording_workbook.png`, new Uint8Array(await preview.arrayBuffer()));

console.log(JSON.stringify({
  sheetName: sheet.name,
  usedRows: table.length,
  usedColumns: table[0].length,
  headers,
  includedCount: included.length,
  roiCounts,
  excludedCounts: Object.fromEntries([...excludedCounts].sort()),
  offsetCounts,
  rowCoverage,
  columnCoverage,
  occupiedApVoxels,
  allApVoxels,
  hiddenApVoxels,
  occupiedMlVoxels,
  allMlVoxels,
  hiddenMlVoxels,
  expectedSessionFileCount: expectedSessionFiles.size,
  actualSessionFileCount: actualSessionFiles.size,
  missingSessionFiles,
  unexpectedSessionFiles,
  lowestFst,
  sourceRows,
  includedSample: [included[0], included.at(-1)],
}, null, 2));
