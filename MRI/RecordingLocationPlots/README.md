# MRI recording-location plotting

The plotting workflows are organized by monkey:

- `Clay/` — Clay session, coronal, sagittal, and trajectory plots.
- `Jim/` — Jim session, coronal, sagittal, and trajectory plots.
- `common/` — shared `unit_table_gof` workbook-matching helper.

Each monkey folder contains its own README and full regeneration runner.
Shared MRI utilities such as `MasterPlotOptions.m` and
`PlotRecordingLocationMRI.m` remain in the parent `MRI` folder.
