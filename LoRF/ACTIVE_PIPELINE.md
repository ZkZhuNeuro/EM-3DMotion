# LoRF Active Pipeline

This folder is organized around the current Jim/Clay receptive-field workflow.

## Jim

1. `GetLoRFs_fromPlx.m`
   - Export waveform files from sorted `SparseNoise.plx` files.
2. `GetRFData_fromwfexp_LoData_Jim.m`
   - Build the Jim RF unit table from waveform exports and matching `.nev`.
3. `RFMappingFunction_Lo_Jim.m`
   - Decode trial structure from `.nev` and compute RF data for each unit.
4. `FitLoRF_EllipseFromTempTable.m`
   - Fit RF ellipses from the saved Jim unit table.
5. `PlotLoRF_Ellipse68_PopulationSummary.m`
   - Run the Jim population summary using the fitted 68% ellipses.

## Clay

1. `GetLoRFs_fromPlx_Clay.m`
   - Export waveform files from sorted `SparseNoise.plx` files.
2. `GetRFData_fromwfexp_LoData_Clay.m`
   - Build the Clay RF unit table from waveform exports and matching `.nev`.
3. `RFMappingFunction_Lo_Clay.m`
   - Decode trial structure from `.nev` and compute RF data for each unit.
4. `FitLoRF_EllipseFromClayTable.m`
   - Fit RF ellipses from the saved Clay unit table.
5. `PlotLoRF_Ellipse68_PopulationSummary_Clay.m`
   - Run the Clay population summary using the fitted 68% ellipses.

## Shared helper

- `FitLoRF_EllipseFromRFMap.m`
  - Reusable ellipse-fitting helper.

## Key data files kept at top level

- `LoRFTable.mat`
- `LoRF_unit_table.mat`
- `LoRF_unit_table_clay.mat`
- `C:\LoData\RF\LoRF_unit_table_with_ellipse.mat`

Large generated RF comparison artifacts are kept outside the repo under
`C:\LoData\RF` so GitHub push limits are not hit.

Older experimental scripts, debug files, and legacy outputs were moved to:

- `backup\old_code\scripts`
- `backup\old_code\artifacts`
