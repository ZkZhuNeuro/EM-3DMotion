import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "P:/Clay/NeuroData/RecordingRecord_Stimulation.xlsx";
const outputDir = "C:/Users/zzhu329/Documents/GitHub/EM-3DMotion/.codex_tmp/clay_smoke/previews";
await fs.mkdir(outputDir, { recursive: true });

const input = await FileBlob.load(inputPath);
const workbook = await SpreadsheetFile.importXlsx(input);

const summary = await workbook.inspect({
  kind: "workbook,sheet,table,region",
  maxChars: 20000,
  tableMaxRows: 12,
  tableMaxCols: 24,
  tableMaxCellChars: 120,
});
console.log(summary.ndjson);

const sheets = workbook.worksheets.items;
for (const sheet of sheets) {
  const used = sheet.getUsedRange();
  console.log(JSON.stringify({ sheet: sheet.name, usedAddress: used?.address ?? null }));
  const preview = await workbook.render({
    sheetName: sheet.name,
    autoCrop: "all",
    scale: 1,
    format: "png",
  });
  const safeName = sheet.name.replaceAll(/[^A-Za-z0-9._-]/g, "_");
  await fs.writeFile(`${outputDir}/${safeName}.png`, new Uint8Array(await preview.arrayBuffer()));
}
