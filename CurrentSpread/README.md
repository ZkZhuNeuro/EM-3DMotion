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

## Five-contact full-tuning discontinuity

`RunAdjacentQuickTuningDiscontinuity.m` replaces the scalar combined-cue AI
continuity check with a full Quick-task tuning comparison. For physical
contacts `-2, -1, StimElec, +1, +2`, each channel is standardized once across
all common-valid trials from all four cues and every available coherence.
Repeated independent trial splits estimate the cross-validated squared tuning
distance across each of the four adjacent gaps. The runner saves session-level
mean and maximum adjacent jumps, cue-specific values, a cohort audit, and
shared-axis histograms:

```matlab
analysis = RunAdjacentQuickTuningDiscontinuity;
```

The default cohort is MT/FST sessions from both monkeys that pass the existing
MonoL and MonoR `p_AI < 0.05` gate and have five available live contacts.
Cross-validated squared distances can be slightly negative when the true
difference is near zero; these values are retained rather than truncated.

`RunPopulationByAdjacentTuningDiscontinuity.m` uses the resulting maximum
adjacent jump to divide valid sessions strictly below versus strictly above
the median. It exports four side-by-side population comparisons for MT 2D,
MT 3D, FST 2D, and FST 3D using the established original stimulation-channel
Quick AI, maximum-response OD, cue colors, monkey markers, and OD-weighted fit
conventions. A session exactly at the median is reported in the split audit
and omitted from both comparison groups:

```matlab
analysis = RunPopulationByAdjacentTuningDiscontinuity;
```

`RunTuningBehaviorPredictionByDiscontinuity.m` compares whether tuning predicts
behavior better below or above the maximum-jump median. All observations from
one session stay in the same cross-validation fold. The 2D populations use the
merged-eye `MergedEyeBias ~ AI + AI:OD` model; 3D populations use four separate
cue-wise `Bias ~ AI` models. The runner reports held-out R-squared, RMSE, and
prediction correlation, equal-session-count resampling intervals, and a
monkey-stratified permutation test for the difference in cross-validated
R-squared:

```matlab
analysis = RunTuningBehaviorPredictionByDiscontinuity;
```

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

## Adjacent-channel linear-model comparison

`RunAdjacentChannelBiasModelComparison.m` implements the nested model requested
for testing whether the two immediately adjacent physical contacts add
predictive power beyond stimulation-contact AI:

```matlab
result = RunAdjacentChannelBiasModelComparison;
```

For every MT/FST x 2D/3D x Dominant/Combined/Stereo/NonDominant group, the
runner compares `Bias ~ AI_STIM` with
`Bias ~ AI_CH-1 + AI_STIM + AI_CH+1`. Both models use the same complete-case
sessions and identical repeated cross-validation folds. The physical Edge
Design channel map is used, so `CH-1` and `CH+1` are probe neighbors rather
than numeric channel-number offsets. Outputs include ordinary, adjusted, and
held-out R-squared summaries; fold-coefficient silhouette plots; a baseline
versus augmented R-squared scatter plot; and a full session/channel audit.
The baseline is intentionally refit on the augmented model's complete-case
cohort, so each comparison applies only to sessions with both adjacent contacts
available. Repeated-partition percentile ranges and coefficient silhouettes
are descriptive stability summaries, not inferential confidence intervals.

The default input is the current
`C:\EM\StimChannelAnalysis\unit_table_gof.mat`, and results are saved under
`C:\EM\CurrentSpread\AdjacentChannelBiasModelComparison`. Both paths can be
overridden explicitly. The default `NeighborRadius=1` follows the requested
adjacent-channel-first analysis; a larger radius can be requested only after
the held-out comparison warrants expansion.

## Quick-task versus stimulation-task tuning correlation

`CorrelateQuickStimNoStimTunings.m` uses the consolidated
`C:\EM\StimTuningAnalysis\unit_table_stim.mat`. For every session, it compares
the stimulation electrode's non-stimulation tuning from the 3D stimulation
task with every channel's tuning from the 3D quick task. It matches the two
coherence grids, z-scores each channel once across the entire cue-by-coherence
matrix, and ranks complete channels by the Pearson correlation pooled across
cues and coherence. This preserves informative relative firing rates among
the four cues. Only the first four and last four Stim coherence columns and
their matching Quick values are included. By default, only Quick channels
within four physical probe positions (200 um at 50 um/contact) of the
stimulation channel are eligible to win. The unconstrained winner is retained
in the session audit so threshold-induced changes can be inspected.

```matlab
[SessionSummary, ChannelCorrelations] = ...
    CorrelateQuickStimNoStimTunings();
```

The default output folder is
`C:\EM\StimTuningAnalysis\QuickVsStimNoStimCorrelation`. It contains a
session-level winner table, the full channel-level correlation table, a MAT
result, a population summary figure, and a session-level scatter of each best
channel's relative probe location versus its Pearson correlation.

## Whole-channel Quick-versus-Stim SSE analysis

`RankQuickChannelsByStimNoStimSSE.m` is a separate, non-correlation analysis.
It is retained as a historical validation utility but is no longer run by the
population pipeline because its winners duplicate the correlation method.
It reads each session's 3D Quick-task `tuning_mean`, selects the shared grid,
and independently Z-scores every Quick channel and the stimulation-electrode
NoStim reference once across the complete cue-by-coherence matrix. It then
ranks channels by the minimum sum of squared errors. This preserves relative
firing-rate offsets among cues and intentionally does not use the inherited
legacy `tuning_z`, which was calculated cue by cue. Only the first four and
last four Stim coherence columns and their matching Quick values are included.

```matlab
[SessionSummary, ChannelSSE] = RankQuickChannelsByStimNoStimSSE();
```

Results are saved under
`C:\EM\StimTuningAnalysis\QuickVsStimNoStimSSE_WholeChannelZScore` without
changing the separate whole-channel correlation outputs.

`PlotBestQuickVsStimNoStimTunings.m` exports one three-panel tuning figure per
session: the minimum-SSE Quick channel, Stim NoStim tuning on the stimulation
channel, and the maximum-correlation Quick channel. Each title reports pooled
Pearson r, SSE, and RMSE for both selected Quick channels across the 32
displayed cells when all four cues are finite (and reports the actual finite n
otherwise). Calling the plotter directly automatically runs either
whole-channel ranking when its prerequisite result MAT is missing or still
uses the legacy cue-wise normalization.
PNG and editable FIG files plus a manifest are saved under
`C:\EM\StimTuningAnalysis\BestSSEChannelTuningComparisons_WholeChannelZScore`.

## Population analysis using the best-correlation Quick channel

`RunPopulationAnalysis_BestQuickChannels.m` selects the maximum pooled Pearson
correlation channel and runs the OD-weighted population analysis with that
channel's 3DMotionQuick AI and OD. It does not run the SSE ranking:

```matlab
analysis = RunPopulationAnalysis_BestQuickChannels;
```

The same four-position/200 um limit is the default for the population runner.
To run the complete MT/FST comparison under both maximum-response OD and LSQ
OD with identical correlation-channel selection, use:

```matlab
results = RunPopulationAnalysis_CorrelationWithin200um_ODComparison;
```

This writes the four analyses plus combined run, population, and AI-by-OD
summary CSV files beneath
`C:\EM\StimTuningAnalysis\BestCorrelationChannelPopulation_Within200um_ODComparison`.

The MonoL/MonoR `p_AI` neural-significance gate and the `Z3D_v_Z2D` 2D/3D
classification are recomputed from cached trial-level 3D Quick responses at
the selected correlation channel. Rows without a valid channel or selection
cache are set to NaN rather than silently falling back to the stimulation
channel. The prepared table and audit retain the exact cache file, the original
and recomputed criteria, and flags for changed gates/classes.

Selected-channel AI is the channel-wise `AI(:, BestChannel)` produced by the
original 3D Quick pipeline from trial-level Quick responses and their SDs.
Selected-channel OD is recalculated directly from that channel's MonoL/MonoR
curves in `tuning_mean` over supported nonzero Quick coherences.
`OD_max_all(BestChannel)` is not used as the OD source; it is retained only for
a discrepancy audit because legacy stored values can differ from the direct
3D Quick calculation. Both the selected AI vector and the OD discrepancy are
retained in the population audit.

The LSQ-OD version is run with:

```matlab
analysis = RunPopulationAnalysis_BestQuickChannels_LSQOD;
```

For every selected Quick channel, it computes the squared error between the
Combined curve and each perspective-cue curve over supported nonzero
coherences. The lower-error perspective cue defines the dominant eye. The
normalized error difference is signed only for eye assignment; the population
models, OD weights, opacity, summaries, and plot annotations always use its
absolute value. The MonoL/MonoR `p_AI` gate is recomputed at the selected
channel, and the LSQ-defined eye determines the dominant-eye tuning used to
recompute `Z3D_v_Z2D`. Thus session selection and 2D/3D classification use the
same selected-channel tuning and LSQ definition as the population analysis.

LSQ results and the direct LSQ-versus-maximum-response OD audit are saved under
`C:\EM\StimTuningAnalysis\BestCorrelationChannelPopulation_LSQOD`. Run
`AnalyzeBestQuickPopulationOutliers_LSQOD` for the matching influence analysis
and tuning/behavior diagnostic plots. No `AP <= 26` anatomical cutoff is used
in either the maximum-response or LSQ analysis.

Correlation-channel results, figures, population tables, prepared input table,
and provenance audits are saved directly beneath:

```text
C:\EM\StimTuningAnalysis\BestCorrelationChannelPopulation
```

`AnalyzeBestQuickPopulationOutliers.m` evaluates session-level influence on the
merged Dominant + NonDominant AI-bias relationship, separately for selected-
channel 2D and 3D units. It groups Cook distance by session, calculates a
leave-one-session-out OD-weighted slope, and calls a session a flattening
outlier only when it exceeds Cook `4/N` or standardized residual 2.5 and its
removal recovers at least 0.01 or 5% of the full slope. This is a sensitivity
analysis: the official population output still contains all eligible sessions.
It saves the all-session influence table, strict outlier table, full-versus-
clean refit summary, and ranked tuning/behavior panels beneath:

```text
C:\EM\StimTuningAnalysis\BestCorrelationChannelPopulation_LSQOD\OutlierAnalysis_SelectedChannelCriteria
```

Each diagnostic panel uses the same selection-cache 3D Quick mean/SEM data as
the recomputed `p_AI` and `Z3D_v_Z2D` criteria, and shows NoStim/Stim behavioral
PSEs plus `Delta Bias = NoStim - Stim`.

For complete channels, the historical SSE metric and correlation obey
`SSE = 2*(N-1)*(1-r)` after the same sample-SD normalization. This identity is
why the active pipeline now runs only the correlation method.

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

`BuildInteractiveGaussianMetaPopulationCache.m` precomputes the MT population
analysis over 1,000 logarithmically spaced sigma values from 0.01 to 100. Each
Quick session is loaded only once. At every sigma, AI is rebuilt from the
channel-standardized Gaussian meta tuning, while signed OD, dominant-eye cue
ordering, and 2D/3D class are rebuilt from the matching raw-FR meta tuning.
The default cohort uses the current workbook-refreshed GOF table without any
adjacent-channel discontinuity exclusions. A row-exclusion CSV can still be
supplied explicitly through `ExcludedRowsFile` for a separate filtered run.
Compact point arrays, OD-weighted population lines, model statistics, and a
per-sigma CSV are saved under
`C:\EM\CurrentSpread\02_gaussian\InteractiveGaussianMetaPopulation`.

`ExploreInteractiveGaussianMetaPopulation.m` opens a slider-based viewer of
that cache. Slider movement only selects saved results; it does not recalculate
meta tuning or population fits. `RunInteractiveGaussianMetaPopulation.m`
builds the default cache when needed and then opens the viewer.

`BuildAllCueR2GaussianMetaObjective.m` reuses the same dense scatter cache and
selects sigma by maximizing the unweighted sum of the four MT 2D per-cue
repeated five-fold cross-validated R-squared values (Dominant + Combined +
Stereo + NonDominant). Every cue uses `DeltaBias ~ AI + AI:OD`, with no
standalone OD main effect.
`ExploreInteractiveGaussianMetaPopulationAllCueR2.m` opens a dedicated viewer
at that optimum, adds the summed-R-squared objective and optimum to the metric
panel, and otherwise leaves the population scatter unchanged. Run
`RunInteractiveGaussianMetaPopulationAllCueR2.m` for the one-command workflow.

`BuildAllCueOrdinaryR2GaussianMetaObjective.m` is the simpler non-CV version.
It maximizes the sum of the four full-sample ordinary R-squared values, with
every cue still using `DeltaBias ~ AI + AI:OD`. The dedicated viewer and
launcher are `ExploreInteractiveGaussianMetaPopulationAllCueOrdinaryR2.m` and
`RunInteractiveGaussianMetaPopulationAllCueOrdinaryR2.m`.

`BuildAllCueType2DistanceGaussianMetaObjective.m` provides the corresponding
distance-based optimization. At every sigma it computes each dot's squared
perpendicular distance to its cue's displayed OD-weighted Type II population
line, averages those squared distances separately for Dominant, Combined,
Stereo, and NonDominant, and minimizes the unweighted sum of the four cue
means. This keeps different cue/session counts from changing the relative cue
weight. `ExploreInteractiveGaussianMetaPopulationAllCueType2Distance.m` opens
the slider at that minimum and shows the four cue-wise mean-distance curves
plus their summed objective. Run
`RunInteractiveGaussianMetaPopulationAllCueType2Distance.m` for the one-command
workflow; it reuses the existing 1,000-sigma scatter cache.

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
