# MRI recording-location plotting

The plotting workflows are organized by monkey:

- `Clay/` — Clay session, coronal, sagittal, and trajectory plots.
- `Jim/` — Jim session, coronal, sagittal, and trajectory plots.
- `common/` — shared `unit_table_gof` workbook-matching helper.

`unit_table_gof` determines which sessions are included. After those sessions
are matched to workbook rows, the current Jim or Clay workbook ROI column is
authoritative for MT/FST labels, colors, and per-area counts. The matcher keeps
both labels in its audit output so disagreements remain visible.

Each monkey folder contains its own README and full regeneration runner.
Shared MRI utilities such as `MasterPlotOptions.m` and
`PlotRecordingLocationMRI.m` remain in the parent `MRI` folder.
