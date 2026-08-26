# 3D Quick and 2D Quick trial cleaning

`RunAllCleanQuickTunings` recalculates the 3D Quick and 2D Quick tuning for
every session in the current `unit_table_gof`, removes noisy firing-rate
observations with the same median/MAD rule used for the stimulation task,
and saves the two tasks separately.

Run the full analysis with:

```matlab
[unit_table_3DQuick_cleaned, unit_table_2DQuick_cleaned] = ...
    RunAllCleanQuickTunings();
```

The source table and the recordings on `P:` are read only. The default output
root is:

```text
C:\EM\QuickTuningCleaningAnalysis
```

The output layout is:

```text
3DQuick\
    unit_table_3DQuick_cleaned.mat
    3DQuick_CleaningSessionManifest.csv
    TrialFiringRates\
    OriginalVsCleanedFigures\
2DQuick\
    unit_table_2DQuick_cleaned.mat
    2DQuick_CleaningSessionManifest.csv
    TrialFiringRates\
    OriginalVsCleanedFigures\
```

For each session, the result table saves the original and cleaned mean, SEM,
and retained trial count. The separate trial-FR MAT file saves the complete
compact firing-rate array, the cell trial counts, and the channel-specific
outlier mask. The CSV manifest provides a quick session-level summary of the
number of excluded channel observations and affected trials.

The figures show original and cleaned tuning side by side. Each corresponding
original/cleaned channel pair uses identical y-axis limits, while different
channels may use different limits so that one noisy channel does not flatten
the rest of the session. 3D Quick produces one figure per session. 2D Quick
produces one figure for each of its two speeds. All 16 channels are arranged
in probe-position order, and the stimulation channel is outlined in orange.

## Filtering rule

Filtering is performed independently for each channel (and unit) within the
task's experimental cell:

- 3D Quick: cue x coherence x channel x unit
- 2D Quick: direction x speed x eye condition x channel x unit

The 3D extractor detects whether the selected recording contains true
zero-coherence trials. It uses the 13-bin grid for those older sessions and
the 12-bin nonzero grid for later sessions; the cleaned table is then aligned
to the 8-, 12-, or 13-column grid already used by `unit_table_gof`.

For an eligible cell, the modified Z-score is:

```text
0.674489750196082 * (FR - median(FR)) / median(abs(FR - median(FR)))
```

An observation is excluded when its absolute score is greater than 3.5.
Quick tasks often have fewer repetitions per cell than the stimulation task,
so the default minimum is 5 finite trials. Cells with fewer than 5 trials or
zero MAD are retained unchanged and counted in the audit fields.

To require 8 trials, matching the stimulation-task setting exactly:

```matlab
RunAllCleanQuickTunings(MinimumTrials=8);
```

To test selected rows or write to another folder:

```matlab
RunAllCleanQuickTunings( ...
    Rows=[27 28], ...
    OutputRoot="C:\EM\QuickTuningCleaningAnalysis_Test", ...
    Overwrite=true);
```

The batch supports checkpointing and resume. Use a new output folder when
changing the threshold or minimum-trial setting, or use `Overwrite=true`.

Run the regression tests with:

```matlab
results = runtests("TestQuickTuningCleaning.m");
assertSuccess(results);
```

## Original versus cleaned AI scatter plots

After the 3D Quick batch finishes, generate four cue-specific AI scatter
plots and a combined 2-by-2 overview with:

```matlab
AIComparison = PlotOriginalVsCleanedQuickAI();
```

Each point is one session's stimulation channel. Both axes are recalculated
from the same new Quick extraction: the x-axis uses every selected trial and
the y-axis applies the MAD filter. This isolates the effect of outlier
removal. The figure folder also contains per-session values, exclusions, and
cue-specific summary statistics as CSV and MAT files.
