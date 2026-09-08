# Clay recording-location plotting

## Main workflow

- `generate_clay_analysis_plots.m` — generates one PNG per included session.
- `generate_clay_projected_by_y.m` — generates MT and FST coronal projections.
- `generate_clay_projected_sagittal.m` — generates combined MT/FST sagittal projections.
- `regenerate_clay_unit_table_gof.m` — regenerates the complete Clay figure set.
- `regenerate_clay_projections_unit_table_gof.m` — regenerates projections only.
- `regenerate_clay_selected_coronal.m` — creates one MT and one FST coronal
  projection in `C:\EM\RecordingLocationPlots\Clay\SelectedCoronal`. The MT
  AP voxel 57 and FST AP voxel 66 sections maximize the corresponding ROI
  mask area across the analysis-covered AP range.
- `regenerate_clay_all_separated_coronal.m` — creates separate blue-MT and
  green-FST projections for every consecutive coronal MRI section, including
  hidden intermediate sections, in
  `C:\EM\RecordingLocationPlots\Clay\SeparatedCoronal`.
- `regenerate_clay_cropped_coronal_pair.m` — creates the title-free cropped
  MT AP voxel 56 and FST AP voxel 62 PDF/PNG pair in
  `C:\EM\RecordingLocationPlots\Clay\CroppedCoronal`.
- `regenerate_clay_session_20240926.m` — regenerates the single-session
  coronal view for the workbook-labeled MT session on 2024-09-26 in
  `C:\EM\RecordingLocationPlots\Clay\SingleSessions`.
- `audit_clay_analysis_sessions.m` — audits the analysis session selection.

Run the complete workflow from MATLAB with:

```matlab
run('C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\MRI\RecordingLocationPlots\Clay\regenerate_clay_unit_table_gof.m')
```

The main inputs are:

- Recording workbook: `P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx`
- Inclusion table: `C:\EM\BehaviorFitting\unit_table_gof.mat`
- Structural MRI and ROI atlas: `P:\MRI\R14008_GridScan`

Outputs are written to `C:\EM\RecordingLocationPlots\Clay`.

## Oblique MT/FST section

`optimize_clay_mtfst_oblique_section.m` searches class-balanced oblique
sections, renders paper figures, and writes quantitative CSV/MAT audits.
`regenerate_clay_oblique_section.m` is the corresponding runner:

```matlab
run('C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\MRI\RecordingLocationPlots\Clay\regenerate_clay_oblique_section.m')
```

Outputs are written to
`C:\EM\RecordingLocationPlots\Clay\OptimizedOblique`. The workflow saves a
highest-match grid-search candidate and a nearby stability-optimized
recommendation. The trace of the MRI's native midsagittal plane is vertical
in the rendered oblique panels, with dorsal up and ventral down. Each
standalone oblique panel includes a horizontal MRI locator whose blue line
shows the oblique plane's intersection with that horizontal section. Because
the MT/FST workbook labels are part of the optimization objective, these are
label-optimized visualizations, not independent anatomical validation of the
labels.

## Reference scripts

- `Clay_RecordingLocationTemplate.m` — single-location reference plot.
- `PlotClayHoleTrajectoriesMRI.m` — coronal hole-trajectory plotting function.
- `RunPlotClayHoleTrajectoriesMRI_AllTables.m` — trajectory example runner.

Shared plotting utilities remain in the main `MRI` folder. The P-drive
reference template remains at `P:\MRI\Grid_Mapping\Clay_RecordingLocationTemplate.m`.
