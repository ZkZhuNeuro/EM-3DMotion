import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "P:/Clay/NeuroData/RecordingRecord_Stimulation.xlsx";
const input = await FileBlob.load(inputPath);
const workbook = await SpreadsheetFile.importXlsx(input);
const sheet = workbook.worksheets.getItem("Sheet1");
const previewDir = "C:/Users/zzhu329/Documents/GitHub/EM-3DMotion/.codex_tmp/clay_smoke/previews";
await fs.mkdir(previewDir, { recursive: true });
const preview = await workbook.render({ sheetName: "Sheet1", autoCrop: "all", scale: 1, format: "png" });
await fs.writeFile(`${previewDir}/Sheet1_updated.png`, new Uint8Array(await preview.arrayBuffer()));
const usedRange = sheet.getUsedRange(true);
const table = usedRange.values;
const headers = table[0].map((value) => String(value ?? "").trim());
const column = Object.fromEntries(headers.map((name, index) => [name, index]));

function excelDateToIso(value) {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  const date = new Date(Date.UTC(1899, 11, 30) + value * 86400000);
  return date.toISOString().slice(0, 10);
}

const included = [];
const excludedCounts = new Map();
for (let i = 1; i < table.length; i += 1) {
  const row = table[i];
  const date = excelDateToIso(row[column.Date]);
  const muaStim = String(row[column.MUAStim] ?? "").trim().toUpperCase();
  const roi = String(row[column.ROI] ?? "").trim().toUpperCase();
  const reasons = [];
  if (!date) reasons.push("missing date");
  if (muaStim !== "Y") reasons.push(`MUAStim=${muaStim || "blank"}`);
  if (!new Set(["MT", "FST"]).has(roi)) reasons.push(`ROI=${roi || "blank"}`);
  if (reasons.length) {
    for (const reason of reasons) excludedCounts.set(reason, (excludedCounts.get(reason) ?? 0) + 1);
    continue;
  }
  included.push({
    workbookRow: i + 1,
    date,
    hole: String(row[column.Hole] ?? "").trim(),
    guideTubeMm: row[column["Guide Tube"]],
    depthMm: row[column.Depth],
    offset: String(row[column.Offset] ?? "").trim(),
    roi,
    muaStim,
    stimElec: row[column.StimElec],
  });
}

const expectedFiles = new Set(included.map((row) => {
  const [x, y] = row.hole.replaceAll(/[\[\]\s]/g, "").split(",");
  return `Clay_${row.roi}_${row.date}_Hole_${x}-${y}.png`;
}));
const outputDir = "C:/EM/RecordingLocationPlots/Clay";
const actualFiles = new Set((await fs.readdir(outputDir)).filter((name) => name.toLowerCase().endsWith(".png")));
const missingFiles = [...expectedFiles].filter((name) => !actualFiles.has(name)).sort();
const unexpectedFiles = [...actualFiles].filter((name) => !expectedFiles.has(name)).sort();
const offsetCounts = new Map();
for (const row of included) {
  const key = row.offset || "blank";
  offsetCounts.set(key, (offsetCounts.get(key) ?? 0) + 1);
}
const nonzeroOffsetRows = included.filter((row) => {
  const parts = row.offset.replaceAll(/[\[\]\s]/g, "").split(",").map(Number);
  return parts.length === 3 && parts.some((value) => value !== 0);
});
const targetDateRows = included.filter((row) => row.date === "2025-09-30");
const rowCoverage = {};
for (const row of included) {
  const [, y] = row.hole.replaceAll(/[\[\]\s]/g, "").split(",").map(Number);
  rowCoverage[y] ??= { MT: 0, FST: 0, total: 0 };
  rowCoverage[y][row.roi] += 1;
  rowCoverage[y].total += 1;
}

const uniqueYRows = Object.keys(rowCoverage).map(Number).sort((a, b) => a - b);
const rowSliceMap = uniqueYRows.map((y) => {
  const apVoxel = 68 - ((29 - y) * 0.8) * 2;
  return { y, apVoxel, mriSliceIndex: Math.round(apVoxel + 1) };
});
const firstSliceIndex = Math.min(...rowSliceMap.map((row) => row.mriSliceIndex));
const lastSliceIndex = Math.max(...rowSliceMap.map((row) => row.mriSliceIndex));
const allSliceIndices = Array.from(
  { length: lastSliceIndex - firstSliceIndex + 1 },
  (_, i) => firstSliceIndex + i,
);
const rowSliceIndices = new Set(rowSliceMap.map((row) => row.mriSliceIndex));
const hiddenSliceIndices = allSliceIndices.filter((index) => !rowSliceIndices.has(index));

const sagittalRows = included.map((row) => {
  const [x, y] = parseVector(row.hole);
  const offset = parseVector(row.offset);
  const edgeOffset = Math.abs(y % 2) === 1 ? 1.4 : 1.8;
  const mlVoxelBase = x > 0
    ? 127 - (((x - 1) * 0.8) + edgeOffset) * 2
    : 127 + (((Math.abs(x) - 1) * 0.8) + edgeOffset) * 2;
  const mlVoxel = mlVoxelBase + 2 * offset[0];
  return {
    ...row,
    x,
    y,
    yParity: Math.abs(y % 2) === 1 ? "odd" : "even",
    mlVoxel,
    roundedMlVoxel: Math.round(mlVoxel),
    sagittalSliceIndex: Math.round(mlVoxel) + 1,
  };
});
const sagittalGroups = {};
for (const row of sagittalRows) {
  const key = row.roundedMlVoxel;
  sagittalGroups[key] ??= { xHoles: new Set(), yParities: new Set(), MT: 0, FST: 0, total: 0 };
  sagittalGroups[key].xHoles.add(row.x);
  sagittalGroups[key].yParities.add(row.yParity);
  sagittalGroups[key][row.roi] += 1;
  sagittalGroups[key].total += 1;
}
const occupiedMlVoxels = Object.keys(sagittalGroups).map(Number).sort((a, b) => a - b);
const allMlVoxels = Array.from(
  { length: Math.max(...occupiedMlVoxels) - Math.min(...occupiedMlVoxels) + 1 },
  (_, i) => Math.min(...occupiedMlVoxels) + i,
);
const hiddenMlVoxels = allMlVoxels.filter((voxel) => !occupiedMlVoxels.includes(voxel));
const sagittalCoverage = Object.fromEntries(Object.entries(sagittalGroups).map(([key, value]) => [
  key,
  {
    ...value,
    xHoles: [...value.xHoles].sort((a, b) => a - b),
    yParities: [...value.yParities].sort(),
  },
]));

function parseVector(value) {
  return String(value ?? "")
    .replaceAll(/[\[\]\s]/g, "")
    .split(",")
    .map(Number);
}

const fstZRows = included
  .filter((row) => row.roi === "FST")
  .map((row) => {
    const offset = parseVector(row.offset);
    const adjustedZMm = Number(row.guideTubeMm) + Number(row.depthMm) + offset[2];
    return {
      ...row,
      offsetZMm: offset[2],
      adjustedZMm,
      plottedYPixel: 48 + 2 * adjustedZMm,
    };
  })
  .sort((a, b) => a.adjustedZMm - b.adjustedZMm || a.date.localeCompare(b.date));

const lowestFstZ = fstZRows.filter((row) => row.adjustedZMm === fstZRows[0].adjustedZMm);
const lowestFstSourceRows = [];
for (const row of lowestFstZ) {
  const source = await workbook.inspect({
    kind: "table",
    sheetId: "Sheet1",
    range: `A${row.workbookRow}:Y${row.workbookRow}`,
    include: "values,formulas",
    tableMaxRows: 2,
    tableMaxCols: 25,
    maxChars: 5000,
  });
  lowestFstSourceRows.push(source.ndjson);
}

console.log(JSON.stringify({
  totalDataRows: table.length - 1,
  includedCount: included.length,
  excludedCounts: Object.fromEntries([...excludedCounts].sort()),
  expectedFileCount: expectedFiles.size,
  actualFileCount: actualFiles.size,
  missingFiles,
  unexpectedFiles,
  offsetCounts: Object.fromEntries([...offsetCounts].sort()),
  nonzeroOffsetCount: nonzeroOffsetRows.length,
  nonzeroOffsetSample: nonzeroOffsetRows.slice(0, 8),
  targetDateRows,
  rowCoverage,
  uniqueYRows,
  rowSliceMap,
  allSliceIndices,
  hiddenSliceIndices,
  sagittalCoverage,
  occupiedMlVoxels,
  allMlVoxels,
  hiddenMlVoxels,
  lowestFstZ,
  lowestFstSourceRows,
  fiveLowestFstZ: fstZRows.slice(0, 5),
  includedSample: [included[0], included.at(-1)],
}, null, 2));
