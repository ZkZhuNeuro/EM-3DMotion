import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const files = [
  "P:/Jim/NeuroData/RecordingRecord_Stimulation_20240515.xlsx",
  "P:/Clay/NeuroData/RecordingRecord.xlsx",
];

for (const file of files) {
  const blob = await FileBlob.load(file);
  const workbook = await SpreadsheetFile.importXlsx(blob);
  const sheets = await workbook.inspect({
    kind: "sheet",
    include: "id,name",
    maxChars: 2000,
  });
  const firstSheet = workbook.worksheets.getItemAt(0);
  const data = await workbook.inspect({
    kind: "region",
    sheetId: firstSheet.name,
    range: "A1:AZ20",
    maxChars: 12000,
    tableMaxRows: 20,
    tableMaxCols: 52,
  });
  const matches = await workbook.inspect({
    kind: "match",
    searchTerm: "44391|MUAStim",
    options: { useRegex: true, maxResults: 50 },
    maxChars: 6000,
  });
  let targetRow = { ndjson: "" };
  let targetValues = "";
  if (file.includes("Jim")) {
    targetRow = await workbook.inspect({
      kind: "region",
      sheetId: firstSheet.name,
      range: "A25:AI25",
      maxChars: 4000,
    });
    targetValues = JSON.stringify(firstSheet.getRange("A25:AI25").values);
    const rows = firstSheet.getRange("A2:AI219").values;
    const included = rows
      .map((row, index) => ({ sheetRow: index + 2, row }))
      .filter(({ row }) => row[12] === "Y" && ["MT", "FST"].includes(String(row[6]).trim()))
      .map(({ sheetRow, row }) => [sheetRow, row[0], row[6], row[8]])
      .slice(0, 10);
    targetValues += `\nINCLUDED ${JSON.stringify(included)}`;
  }
  process.stdout.write(`FILE ${file}\n${sheets.ndjson}\n${data.ndjson}\n${matches.ndjson}\n${targetRow.ndjson}\n${targetValues}\n`);
}
