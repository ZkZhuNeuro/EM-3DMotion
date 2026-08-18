# Current-spread analyses

This folder contains organized copies of the MATLAB analyses previously kept in
`P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\Clustering`.
The original files on `P:` are unchanged.

## Organization

- `01_step_weight`: four cross-validated spatial-weight models plus the retained
  legacy summed-tuning test.
- `02_gaussian`: channel-wise Gaussian weighting, sigma diagnostics, and
  standardized cross-validated R-squared versus sigma tests.
- `03_cluster_weighting`: Gaussian weighting after grouping adjacent channels into AI clusters.
- `04_discontinuity`: single-session plots, spline-discontinuity measures, and prediction-error tests.
- `common`: shared input-path and result-saving utilities.

## Inputs and outputs

The current step-weight and Gaussian cross-validation analyses load the updated
`C:\EM\PopulationAnalysis\unit_table_gof.mat`. The behavioral target is combined-cue
`Behav_bias_NminusS(1)`, defined as non-stimulation PSE minus stimulation PSE.
Firing-rate analyses map these updated rows to the older multichannel array with
`OriginalRecIdx`. Shared paths are defined in `common/currentSpreadInit.m`.

Running a script creates a dedicated output folder under:

```text
C:\EM\CurrentSpread\<analysis-group>\<script-name>\
```

## Quick-task versus stimulation-task tuning correlation

`CorrelateQuickStimNoStimTunings.m` uses the consolidated
`C:\EM\StimTuningAnalysis\unit_table_stim.mat`. For every session, it compares
the stimulation electrode's non-stimulation tuning from the 3D stimulation
task with every channel's tuning from the 3D quick task. It matches the two
coherence grids, z-scores each cue independently, and ranks complete channels
by the Pearson correlation pooled across cues and coherence.

```matlab
[SessionSummary, ChannelCorrelations] = ...
    CorrelateQuickStimNoStimTunings();
```

The default output folder is
`C:\EM\StimTuningAnalysis\QuickVsStimNoStimCorrelation`. It contains a
session-level winner table, the full channel-level correlation table, a MAT
result, a population summary figure, and a session-level scatter of each best
channel's relative probe location versus its Pearson correlation.

The four refactored step-weight scripts save:

- the R-squared figure as both `.fig` and 300-dpi `.png`;
- the plotted values in `.csv`;
- the full result structure, including held-out predictions, fitted weights,
  fold coefficients, selected rows, and analysis metadata, in `.mat`.

The retained legacy scripts use `common/currentSpreadSaveResults.m`, which saves
all open figures, selected workspace variables, and `run_info.mat`.

The four step-weight scripts other than `WeightSteps_sumTuning.m` create a standardized
`combined_cue_channels_vs_cv_r2` figure and data file. They use Jim MT 2D units
with good combined-cue behavioral fits and report repeated five-fold
cross-validated R-squared as the centered window expands from 1 to 15 channels.
All models fit the same equation, `DeltaBias = beta0 + beta1 * weighted AI`, and
optimize spatial weights using training sessions only.

- `FitRelativeChannelAIWeights.m`: one nonnegative weight per included relative
  channel, applied to stored combined-cue channel AIs.
- `FitRelativeChannelFRWeights.m`: one nonnegative weight per included relative
  channel, applied to standardized combined-cue firing rates before calculating AI.
- `FitDistanceShellAIWeights.m`: symmetric, nonnegative, monotonically decreasing
  distance-shell weights applied to stored combined-cue channel AIs.
- `FitDistanceShellFRWeights.m`: the same distance-shell model applied to
  standardized combined-cue firing rates before calculating AI.

Weights are normalized to sum to one. Missing channels are excluded from the
corresponding session-specific weighted average. Weight and regression fitting
occur only in each outer training fold; held-out sessions determine the reported
R-squared relative to the corresponding training-fold mean prediction.

Each of these four scripts also creates a `weight_distributions` subfolder. It
contains one `.fig`, `.png`, and summary `.csv` for each 1, 3, ..., 15-channel
window. Each plot shows the 25 outer-training-fold weight profiles, their mean,
and +/- one standard deviation. Combined summary and individual-fit CSV files
are included in the same subfolder. Distance-shell parameters are expanded onto
signed relative channel positions so their enforced symmetry is visible.

`PlotRelativeChannelBiasPrediction.m` follows up on the large positive-side
RelativeChannel weights. It reproduces the population equation
`Behav_bias_NminusS ~ combined-cue channel AI` for the stimulation channel and
relative positions +3 and +4. It saves separate population-style scatters,
matched-session comparisons, strictly held-out prediction scatters, model
summaries, and session-level channel mappings under its own output folder.

`PlotAllCueAIODAcrossRelativeChannels.m` extends that check to relative
positions 0 through +4 and overlays Dominant, Combined, Stereo, and
NonDominant cues using the exact colors from the population analysis. AI and
signed OD both come from the local channel; local OD sign reassigns dominant
and non-dominant eye at every position. Non-dominant DeltaBias is sign-flipped
for plotting and modeling, matching the population merged-eye analysis.
Marker opacity is absolute OD, and the displayed lines are the population
code's OD-weighted `DeltaBias ~ AI` fits. Each panel reports the AI-by-OD
p-value from the merged Dominant + flipped-NonDominant perspective-cue model.
The saved tables report both the population statistical formula
`DeltaBias ~ AI + AI:OD` and literal MATLAB `DeltaBias ~ AI*OD` (which also
contains an OD main effect), along with every plotted point, exclusion reason,
and local dominance-sign change relative to the stimulation channel.

`FitGaussianChannelAIWeights.m` and `FitGaussianFRWeights.m` create matching
combined-cue Gaussian analyses. They evaluate sigma values from 0.01 to 100,
plot repeated five-fold cross-validated R-squared against sigma, and save the
Gaussian profile corresponding to the largest mean cross-validated R-squared.

`PlotOriginalVsOptimizedAIOD.m` reproduces the population-analysis perspective
scatter convention for Jim MT 2D sessions: dominant and non-dominant eyes are
merged, marker opacity represents absolute ocular dominance, and an OD-weighted
fit is shown. It compares the stimulation-electrode values with Gaussian
channel-AI and Gaussian firing-rate optimizations of the `AI + AI:OD` model.
The channel-AI method uses the signed mean OD across available channels. The
firing-rate method calculates signed OD from its Gaussian-weighted raw
meta-tuning curves while calculating AI from the corresponding z-scored
meta-tuning curves. Each method uses its own OD sign to assign the dominant and
non-dominant eye before negating the non-dominant-eye behavioral bias; only the
OD magnitude is then used for model weighting and marker opacity.
Gaussian sigma is selected exclusively by the matching combined-cue
cross-validated analysis and is held fixed for the perspective-cue plot.

`OptimizePerspectiveAIODWeights.m` is a separate perspective-cue optimization.
For every candidate sigma, it reassigns dominant and non-dominant eyes using
that method's signed OD, forms merged-eye Delta Bias, and evaluates
`MergedEyeDeltaBias ~ AI + AI:OD` with session-grouped cross-validation. It
selects sigma from the repeated-CV curve and also reports nested
selection-pipeline CV R-squared, in which each outer fold selects sigma using
only its training sessions. The
script saves the sigma curves, best Gaussian profiles, optimized scatter plots,
per-sigma tables, nested-fold sigma selections, point data, and a summary table.
`AI + AI:OD` intentionally matches the population-analysis model; unlike the
literal MATLAB formula `AI*OD`, it does not add a standalone OD main effect.
Full-model p-values at the selected sigma and the OD-weighted AI-only display
line are descriptive; cross-validated R-squared is the optimization metric.

`OptimizeFilteredMetaFRAIOD.m` rebuilds the FR-meta analysis without using the
stimulation-electrode `p_AI` or `ND` fields for neural selection. It begins with
all Jim recordings (MT and FST), maps each row through `OriginalRecIdx`, and
recomputes the project's trial-level direction test separately for the left-
and right-eye perspective cues on every non-dead channel. A channel enters the
meta tuning only when both raw p-values are below 0.05. The fixed analysis
cohort is then selected from an equal-weight raw meta curve: the meta curve
must itself pass the same two eye-specific direction tests before using the
legacy partial-correlation sign rule, `Z3D - Z2D < 0`. This uniform neural gate
is defined before sigma optimization so the candidate cohort cannot change
with sigma. The optimized AI comes from Gaussian-weighted, channel-standardized
firing-rate meta curves; signed OD comes from the matching raw meta curves and
reassigns the dominant eye. The script saves a session-level selection audit,
a per-channel p-value audit, ROI-specific flow counts, the R-squared/sigma and
effective-channel diagnostics, and original-versus-uniform-versus-optimized
perspective scatter plots. It handles both 12-bin and 13-bin `NeuroAll` records
explicitly and excludes the zero-coherence bin from the direction test.

`OptimizeFilteredMetaFRAIOD_JimMT.m` runs the same cleaned analysis specifically
for Jim MT. It begins with all Jim MT recordings, then applies the per-channel
two-eye tuning screen and the cleaned uniform-meta 2D gate before optimization.
It also saves one 4-by-4 channel-tuning page for every included recording. Tiles
follow physical channel order. Dead channels are blank, excluded live channels
use dashed left/right-eye curves, and included channels use solid curves with
their Gaussian weight printed in the title. A black frame marks every included
channel, with frame opacity encoding its normalized distance weight. The pages
are saved individually and combined into a multipage PDF.

Run a script directly in MATLAB; it resolves the project and input paths without
requiring MATLAB's current folder to be changed first.
