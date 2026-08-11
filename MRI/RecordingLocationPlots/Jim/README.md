# Jim recording-location plotting

This folder contains the Jim-specific MRI recording-location workflow.

## Main workflow

- `generate_jim_recording_location_plots.m` — generates session, coronal, and sagittal PNGs.
- `regenerate_jim_unit_table_gof.m` — regenerates the complete included Jim set.
- `regenerate_jim_projections_final_offsets.m` — regenerates only coronal and sagittal projections.
- `regenerate_jim_sagittal_left_hemisphere.m` — regenerates only the left-hemisphere sagittal set.
- `../common/getWorkbookRowsFromUnitTableGof.m` — shared workbook-to-analysis-session matcher.

Run the complete workflow from MATLAB with:

```matlab
run('C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\MRI\RecordingLocationPlots\Jim\regenerate_jim_unit_table_gof.m')
```

The main inputs are:

- Recording workbook: `P:\Jim\NeuroData\RecordingRecord_Stimulation_final.xlsx`
- Inclusion table: `C:\EM\BehaviorFitting\unit_table_gof.mat`
- Structural MRI and ROI atlas: `P:\MRI\R12059_GridScan\anaGrid`

Sagittal plots mirror the coronal display coordinate into the NIfTI first
dimension, selecting left MRI ML voxels 156–168, and use the dedicated
`R12059_allROIs_LVE00_Left_org2Grid_updated.nii.gz` ROI mask at those same
indices. The generator rejects sagittal MRI voxels on the wrong side of the
midsagittal reference.

Outputs are written to `C:\EM\RecordingLocationPlots\Jim`.

## Oblique MT/FST section

`optimize_jim_mtfst_oblique_section.m` runs the same class-balanced,
distance-constrained oblique-plane analysis used for Clay. It uses Jim's
left-only ROI atlas (MT label 28; FST label 24), and renders the trace of the
MRI's native midsagittal plane vertically with dorsal up. Each standalone
oblique panel includes a horizontal MRI locator whose blue line shows the
displayed oblique plane. Run it with:

```matlab
run('C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\MRI\RecordingLocationPlots\Jim\regenerate_jim_oblique_section.m')
```

Outputs are written to
`C:\EM\RecordingLocationPlots\Jim\OptimizedOblique`. The workflow writes
paper-ready PNG/PDF/FIG panels plus CSV, MAT, and text audits. The oblique
plane is optimized using the workbook's MT/FST labels, so the result is a
label-optimized visualization rather than independent anatomical validation.
The recommended nominal plane must satisfy the 2.5-mm projection-distance
limit. If Jim's full +/-0.5-degree and +/-0.5-mm robustness neighborhood
cannot also remain within that same limit, the perturbations are retained as
a stability test and the CSV/text audit explicitly reports the fallback mode
and neighborhood distances.

## ROI configuration

The ROI label numbers and colors are defined near the top of
`generate_jim_recording_location_plots.m`. The same reference configuration
is also present in `Jim_RecordingLocationTemplate.m`.

`audit_jim_roi_labels.m` compares the combined atlas against the individual
Jim ROI masks and writes its audit beside the script.

## Additional reference scripts

- `Jim_RecordingLocationTemplate.m` — single-location reference plot.
- `PlotJimHoleTrajectoriesMRI.m` — coronal hole-trajectory plotting function.
- `RunPlotJimHoleTrajectoriesMRI_Stimulation20250331.m` — trajectory example runner.

Shared plotting utilities remain in the main `MRI` folder. The P-drive
reference template remains at `P:\MRI\Grid_Mapping\Jim_RecordingLocationTemplate.m`.
