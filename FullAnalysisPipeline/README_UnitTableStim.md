# Population 3DMotionStim tuning table

`RunAllUnitTableStimTunings.m` creates a new population table without
modifying `unit_table_gof.mat` or any recording on `P:`:

```matlab
[unit_table_stim, manifest] = RunAllUnitTableStimTunings();
```

Default output folder:

```text
C:\EM\StimTuningAnalysis
```

The pipeline is table-driven. For each of the 251 rows, it scans only the
exact folder in `Paths` for a stem-matched MUA `3DMotionStim` TInfo/SelIndex
pair. `Names` is not used because it contains the corresponding Quick pair.
The source table and source recording files are read only.

## Tuning fields

The output variable is named `unit_table_stim`. It contains all original
`unit_table_gof` columns plus these six primary curve columns:

- `stim_tuning_mean_noStim` and `stim_tuning_SEM_noStim`;
- `stim_tuning_mean_stim` and `stim_tuning_SEM_stim`;
- `stim_tuning_mean_merged` and `stim_tuning_SEM_merged`.

Each cell contains the MUA unit-1 array in cue x coherence x acquisition
channel order, normally `4 x 13 x 16`. The 13-bin grid includes zero
coherence and is stored explicitly in `stim_tuning_coherence`. The merged
curves are calculated from all pooled trials, not by averaging the two group
means. Per-cell trial counts, cue names, channel map, source filenames,
fingerprints, eye-check status, extraction counts, errors, and processing
status are also stored.

`NChannels` in the source table is authoritative. Historical Stim files may
contain trailing stimulation-monitor rows after the probe MUA rows; the
builder retains acquisition rows `1:NChannels` consistently in every tuning
array and trial firing-rate array. The extraction summary records the
original, retained, and dropped channel indices. A file with fewer channels
than the table expects is rejected instead of silently padded.

## Trial firing rates

Trial firing rates are not embedded in the population table. Each successful
session has a linked file under `TrialFiringRates`, containing one
`StimTrialFR` struct with:

- `FiringRateHz`: analyzed trial x channel x unit;
- `TrialSummary`: the aligned trial metadata and Stim/NoStim flag;
- source and extraction provenance; and
- the coherence axis, cue names, and channel map.

The file does not contain `Neuro.All` or duplicate copies for the three trial
subsets. The `ElectricalStim` column in `TrialSummary` selects the groups.

## Restart and audit behavior

Each trial-FR file is finalized atomically as soon as its session completes.
The population runner atomically checkpoints `unit_table_stim.mat` and
`StimTuningSessionManifest.csv` every ten attempted rows, avoiding repeated
writes of the large inherited table; `CheckpointEvery` is configurable.
Rerunning the command reuses only successful rows whose input signature,
analysis settings, tuning cells, and trial-FR provenance still validate.
If a process ends after an atomic trial-FR file is written but before the
large table checkpoint, the next run reconstructs all three means, SEMs, and
counts from that trial file without rereading the recording. Failed or stale
rows are retried. Use a new output folder or
`OverwriteOutput=true` when intentionally changing the analysis definition.

For v7.3 recordings whose uncompressed `TrialInfo` exceeds 512 MiB, the
builder reads 64 contiguous trials at a time and stages a temporary slim
copy containing only fields needed for tuning and the optional eye check.
The temporary data are removed on success or error, and saved provenance
continues to point to the original `P:` files. The threshold can be changed
with `MaxDirectTrialInfoBytes` when calling `BuildUnitTableStimTunings`.

The version/vergence check follows the Quick pipeline when available, keeps
zero-coherence trials outside that legacy helper, and intentionally skips
20-May-2022 just as the original Quick analysis did. A failed/unavailable eye
check is recorded as `SuccessWithEyeCheckWarning` unless
`RequireEyeCheck=true` is requested.

## Session tuning figures

To export the 16-channel tuning figures from the completed table, run:

```matlab
PlotUnitTableStimSessionTunings();
```

This creates `TuningFigures_16Channels_ZScore` under the analysis folder, with
separate `NoStim`, `Stim`, and `Merged` subfolders. Each session has one 2-by-8
PNG per trial group, ordered by physical probe position and labeled by
acquisition channel. Within each trial group, every cue of each channel is
Z-scored independently across coherence, matching the existing
`unit_table_gof.tuning_z` convention. SEM is divided by the same cue- and
channel-specific standard deviation. All three figures for a session share one
Z-score axis range. MATLAB `.fig` output is optional:

```matlab
PlotUnitTableStimSessionTunings(SaveFIG=true);
```
