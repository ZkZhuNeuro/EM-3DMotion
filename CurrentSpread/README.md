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

`RunQuickTuningWindowDiameterStim2D.m` measures full-tuning heterogeneity over
the complete physical contact window `-4:4` for MT and FST sessions classified
as 2D at the stimulation channel. It calculates all 36 cross-validated pair
distances among the nine contacts and defines the window diameter as their
maximum. The stimulation-channel cohort also requires the source MonoL and
MonoR `p_AI < 0.05` gate. All nine physical positions must exist on the probe.
Dead non-stimulation contacts inside the window are skipped rather than
excluding the session; the audit records the live-contact and evaluated-pair
counts. At least two contacts, including the stimulation contact, must be live
and contain common-valid Quick-task trials. The default outputs are written beneath
`C:\EM\StimTuningAnalysis`, including an MT/FST overlaid probability histogram,
session audit, all pair distances, diameter-pair span summary, and MAT result:

```matlab
analysis = RunQuickTuningWindowDiameterStim2D;
```

Use `RelativePositions=-2:2` with a separate output folder to run the same
analysis on a five-position window while preserving the default `-4:4`
artifacts.

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

## Weighted centered-window meta-tuning comparison

`RunWeightedMetaTuningBiasComparison.m` tests whether combining complete Quick
tuning curves across a centered physical-contact window improves behavioral-
bias prediction relative to a reconstructed stimulation-contact-only baseline:

```matlab
result = RunWeightedMetaTuningBiasComparison; % CH-1:CH+1
```

Each channel is z-scored once across all valid Quick trials, cues, and
coherences. Nonnegative weights constrained to sum to one form a trial-level
meta tuning. Cue-specific meta AI is calculated from all available matched
nonzero coherence pairs, while meta OD uses the same weights on the raw-FR
meta curves. For the default radius-1 window, the baseline is the nested
weight vector `[0 1 0]` on the same three-channel complete-trial support.

The primary cue-wise model is `Bias ~ MetaAI`; `Bias ~ MetaAI + MetaAI:OD` is
exported as a secondary sensitivity analysis. The all-cue analysis learns one
shared spatial weight vector per area/type with separate cue-specific
regression coefficients; the Stereo-only analysis learns its own weight
vector. Original stimulation-site unit classes, cue labels, and behavioral
responses remain fixed, while meta-OD sign changes are audited rather than
used to relabel outcomes.

Weights and behavioral coefficients are refit only inside each outer training
fold. Twenty repeated five-fold session-grouped splits compare the optimized
meta readout with the center-only baseline on identical sessions, observations,
folds, and training-mean null predictions. Outputs default to:

```text
C:\EM\CurrentSpread\WeightedMetaTuningBiasComparison_Radius1
```

For the five-contact `CH-2:CH+2` version:

```matlab
result = RunWeightedMetaTuningBiasComparison( ...
    NeighborRadius=2, WeightStep=0.1, ...
    OutputFolder="C:\EM\CurrentSpread\WeightedMetaTuningBiasComparison_Radius2");
```

The radius-2 run uses a documented 0.10 simplex grid (1,001 candidate weight
vectors). A 0.05 five-weight grid would contain 10,626 candidates and would be
46 times larger than the radius-1 search. The five-channel baseline is the
one-hot center vector `[0 0 1 0 0]` on the same five-contact trial support.
Because radius 1 and radius 2 require different complete-contact cohorts, their
results are descriptive side-by-side comparisons rather than a direct nested
test of whether `CH-2/CH+2` add value beyond `CH-1/STIM/CH+1`.

For the nine-contact `CH-4:CH+4` exploratory version:

```matlab
result = RunWeightedMetaTuningBiasComparison( ...
    NeighborRadius=4, WeightStep=0.2, ...
    OutputFolder="C:\EM\CurrentSpread\WeightedMetaTuningBiasComparison_Radius4");
```

The radius-4 run uses a coarser 0.20 simplex grid containing 1,287 candidate
weight vectors. Its center-only baseline is
`[0 0 0 0 1 0 0 0 0]` on the identical nine-contact support. Requiring a
complete centered nine-contact window further reduces the eligible cohort.
When the output folder and weight step are omitted, the runner now derives a
radius-specific external folder and selects this safe coarse grid automatically.
Therefore, radius-1, radius-2, and radius-4 results should not be interpreted
as a strict nested comparison unless all window sizes are refit on the same
nine-contact cohort, trial support, and CV partitions.

The output bundle includes group and cue summaries, fold/full-fit weights,
cache/reconstruction audits, ordinary-versus-held-out R-squared figures,
weight silhouettes, and a complete MAT result.

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

The interactive population implementation is organized under
`02_gaussian/interactive_population`:

- `common`: area-specific cache generation and the shared slider viewer;
- `channel_prediction`: channel-first behavioral prediction and its viewer;
- `cv_ai_od`: repeated-CV `DeltaBias ~ AI + AI:OD` objective and viewers;
- `ordinary_ai_od`: full-sample ordinary-R-squared objective and viewers;
- `type2_distance`: distance-to-displayed-Type-II-line objective and viewers.

`BuildInteractiveGaussianMetaPopulationCache.m` supports `Area="MT"` or
`Area="FST"` and precomputes 1,000 logarithmically spaced sigma values from
0.01 to 100. Each Quick session is loaded only once. Away from the
stimulation-channel endpoint, AI is rebuilt from channel-standardized Gaussian
meta tuning, while signed OD, dominant-eye cue ordering, and 2D/3D class are
rebuilt from the matching raw-FR meta tuning. At `sigma = 0.01`, the cache is
anchored to the population pathway's exact fixed-`StimElec` values: stored AI,
OD calculated from `tuning_mean(:, :, StimElec)`, and stored `Z3D_v_Z2D`.
The builder asserts equality of the endpoint cohort and cue-valid point counts.
To preserve source-row identity with `OD_Analysis`, the default cohort loads
the supplied GOF MAT artifact unchanged and does not refresh it from recording
workbooks; `RefreshFromWorkbooks=true` remains available as an explicit
override. Adjacent-channel discontinuity exclusions are not applied by
default. Each cache contains both meta-2D and meta-3D point-validity arrays and
population statistics.

The cache also stores a non-meta, channel-first representation. A neuron/site
is included only when its source `unit_table_gof.p_AI(2)` (MonoL) and
`p_AI(3)` (MonoR) are both finite and below 0.05. These source tests govern the
stimulation contact; every contributing neighboring contact must separately
pass its own raw Quick-task MonoL and MonoR direction-tuning tests. Channels
must also be live and have a finite predictor, position, and nonzero signed OD.
Each eligible channel retains its own AI and signed OD. The default model uses
each channel's **dominant-eye
AI multiplied by absolute local OD** to predict every behavioral condition c
(Dominant, Combined, Stereo, NonDominant). The dominant physical eye is chosen
independently for each channel from the sign of that channel's OD:

`channel bias(c) = beta0(c) + beta1(c)*AI_dominant*abs(OD)`.

The predicted channel biases are then averaged with Gaussian weights centered
on `StimElec`, renormalized over the eligible channels in that session. For
every candidate sigma, ordinary least squares independently fits an intercept
and slope for each cue (eight coefficients total). These coefficients are
shared across channels and sessions within each cue. The four fits use all
valid observations without cross-validation. OD is already embedded in the
single predictor; there is no separate OD coefficient or AI-by-OD interaction.
Sigma maximizes the unweighted sum of the four centered ordinary R-squared
values: `sum_c (1-SSE_c/SST_c)`. All four conditions must have finite R2.
The observed behavioral Dom/NonDom targets are assigned once by the signed OD
of the stimulation channel, independent of sigma. Source physical cue indices
are retained in the observation audit; the per-channel audit records whether
MonoL or MonoR supplied the locally dominant AI. The
2D/3D selector for this model uses the stored
stimulation-channel `Z3D_v_Z2D` sign; it does not construct a meta tuning curve.
Ordinary fits and stimulation-only CV comparisons use the same shared neuron
selector, including the source both-eye gate, a valid behavioral fit, and a
unique live stimulation contact with finite predictor. A significant neighbor
cannot admit a nonsignificant stimulation neuron. With the current source file,
the Max-OD analysis includes **63 MT 2D sites and 30 FST 3D sites** in both fits.
Recomputed stimulation-contact p-values can disagree with the source table;
they are retained for audit but do not replace its `p_AI`. The neuron audit
reports both sets of tests and every exclusion reason; the channel-weight audit
records the p-value source for each contributing channel. Cache schema 6 stores
source p-values explicitly; older caches read them from their original
`StateFile` after source-row identity checks.

The cache accepts `ODDefinition="Max"` (the default) or
`ODDefinition="Correlation"`. Correlation OD is
`atanh(PearsonR(Combined,MonoL)) - atanh(PearsonR(Combined,MonoR))` on the
common finite coherence support, matching the Fisher-Z correlation method in
`OD_Analysis`. Its sign controls dominant-eye cue ordering and the
dominant-curve choice for 2D/3D classification; its absolute value controls OD
weighting and marker opacity. Correlation-OD caches are kept separate under
`InteractiveGaussianMetaPopulation\CorrelationOD\<Area>`.
Correlation-OD viewers use `MarkerFaceAlpha = 1-exp(-abs(OD))`, matching the
Fisher-Z population figures, and use 0.95 edge opacity. Max-OD viewers retain
the original `MarkerFaceAlpha = abs(OD)` mapping and 0.85 edge opacity.

Use the two top-level apps instead of method-specific launcher lists:

- `RunGaussianMetaPopulationApp.m` opens the Max-OD app;
- `RunGaussianMetaPopulationCorrelationODApp.m` opens the separate
  correlation-OD app.

Each app provides dropdowns for area (MT/FST), stimulation-channel population
(2D/3D), and optimization method. It opens on the channel-first ordinary R2
view, which overlays Dominant, Combined, Stereo, and NonDominant fitted
predicted versus observed biases in one upper-left population plot. It uses
the same condition colors, Jim/Clay markers, bottom sigma slider and appearance
controls as the legacy viewers. The Gaussian profile, condition-wise ordinary R2,
and statistics are on the right. Dot opacity uses stimulation-channel |OD|.
Sigma is selected by maximum summed ordinary R2. The earlier meta-tuning CV,
ordinary, and Type-II-distance views remain available for comparison. Changing
a dropdown replaces the displayed cached view. If a cache or objective is
missing, stale, or predates the channel-first inputs, the app rebuilds the
requested channel-first objective from the existing neural cache when possible;
it does not refit the other three methods for this update. The dominant-AI×OD
ordinary calculation has objective schema 5 and output folders named
`<Area>\<UnitType>\ChannelFirstBiasPrediction_DominantAIxOD_OrdinaryR2_SourceStimBothEyes`.
Earlier result folders are preserved as historical outputs, not used by the app.
The earlier Combined-AI calculation remains available by passing
`PredictorMode="CombinedAI"` explicitly.
The previous channel-first cue-specific AI + AI:OD CV model remains callable
with `BuildGaussianChannelBiasPredictionObjective(FitMethod="CV", ...)` and
uses `ChannelFirstBiasPrediction_DomNonDom_SourceStimBothEyes` for newly gated fits.

`RunGaussianCombinedAIStimChannelCVComparison` now defaults to testing whether
Gaussian pooling of **dominant-eye AI×|OD|** improves prediction over the same
predictor at the stimulation channel alone. Pass `PredictorMode="CombinedAI"`
to reproduce the earlier Combined-AI comparison.
Both models fit an intercept and slope separately for each behavioral cue
(eight betas). The baseline uses the actual `StimChannel` contact with a
literal weight of one; it does not use a small-sigma approximation or replace
an unavailable stimulation contact with a neighbor. Both models use the same
sessions as the ordinary fit, whose stimulation neuron passes both source-eye
tests and has a live, finite stimulation-channel predictor. Session inclusions
and exclusions are exported for audit.

The default evaluation uses five session folds repeated five times. The
Gaussian model selects sigma by five-fold inner CV using only the outer
training sessions. The stimulation-only model has no sigma to select; its
cue-specific betas are fitted on the same outer training sessions. Paired
outer-fold error differences use the same variance-corrected test described
below, with positive differences favoring Gaussian pooling. Results default
to `<Area>\<UnitType>\DominantAIxOD_GaussianVsStimOnly_CV_SourceStimBothEyes` under `C:\EM`.

```matlab
addpath('02_gaussian/interactive_population/channel_prediction');
analysis = RunGaussianCombinedAIStimChannelCVComparison;
```

To evaluate split robustness with 100 repeats of the five-fold **outer** CV
(500 paired outer-test evaluations), retaining five-fold inner CV for sigma:

```matlab
analysis = RunGaussianCombinedAIStimChannelCVComparison( ...
    PredictorMode="DominantAIxOD", NumRepeats=100, NumFolds=5, ...
    NumInnerFolds=5, RandomSeed=1, ...
    OutputFolder="C:\EM\CurrentSpread\02_gaussian\InteractiveGaussianMetaPopulation\MT\2D\DominantAIxOD_GaussianVsStimOnly_CV_Outer100_SourceStimBothEyes");
```

`OuterRepeatMetrics.csv` records the held-out MSE and R2 for each complete
outer repeat, including each cue. `OuterRepeatRobustness.csv` reports the
fraction of repeats and folds improved and the spread of the error difference.
`OuterSigmaRobustness.csv` records the distribution of selected sigmas across
outer fits. `OuterCVRobustness.png` visualizes these results. Percentiles across
random splits describe split sensitivity; they are not population confidence
intervals, and the fraction of improved repeats is not a p-value. The corrected
paired significance test remains separate. Seed 1 preserves the first five
outer repeats from the initial five-repeat run exactly.

`SaveGaussianDominantAIxODAreaR2Scatters` places the MT 2D and FST 3D
repeat-wise R2 comparisons in one two-panel figure with fixed colors: orange
for MT and purple for FST. It uses no performance color gradient and requires
the corrected source-both-eye cohort. Its default output folder is
`C:\EM\CurrentSpread\02_gaussian\InteractiveGaussianMetaPopulation\DominantAIxOD_MT2D_FST3D_SourceStimBothEyes`.

For the matched **correlation-OD** comparison of both channel predictors in MT
2D and FST 3D, run:

```matlab
addpath('02_gaussian/interactive_population/channel_prediction');
result = RunGaussianCorrelationODPredictorComparison;
```

This runs 100 repeats of five-fold outer CV with five-fold inner CV for both
Combined AI and dominant-eye AI times absolute correlation OD. Here OD is
`atanh(r(Combined,MonoL)) - atanh(r(Combined,MonoR))`; the raw absolute Fisher-z
difference is used, without clipping or the viewer's opacity transformation.
Its sign assigns each channel's dominant eye and the stimulation site's
behavioral Dom/NonDom labels. Both predictors must share neurons, contributing
channels, observations, sigma grid, and inner/outer folds. The cohorts remain
63 MT 2D and 30 FST 3D neurons for the current input.

The output includes a four-panel original-versus-Gaussian nested-CV R2 figure
(columns MT/FST, rows Combined AI/dominant AI x |OD|), signed-rank split
robustness statistics, corrected CV improvement p-values, and a separate
direct neural-predictor scatter. Colors remain orange for MT and purple for
FST. Results default to
`C:\EM\CurrentSpread\02_gaussian\InteractiveGaussianMetaPopulation\CorrelationOD\BothPredictors_MT2D_FST3D_SourceStimBothEyes`.
`OutputFolder` overrides that root; Max-OD and older results are preserved.

`RunGaussianCorrelationODBetaComparison` plots ordinary fitted coefficients
versus sigma for both predictors, with MT/FST rows and four cue columns.
Solid lines indicate Combined AI; dashed lines indicate dominant AI x |OD|.
Separate figures show slope beta1, intercept beta0, scale-adjusted slope
`beta1 * SD(pooled predictor)`, and predicted DeltaBias. The DeltaBias figure
shows individual neuron curves and their median; an across-neuron mean would
be flat because of the fitted intercept. These are full-sample ordinary fits,
not averages of outer-CV coefficients or held-out predictions. Outputs and
underlying predictions default to the comparison folder's `BetaVsSigma`
subfolder; `OutputFolder` and `SigmaValues` are optional overrides.

```matlab
betaComparison = RunGaussianCorrelationODBetaComparison;
```

`RunGaussianChannelCVComparison` separately compares the previous cue-AI+AI:OD model with the
Combined-AI model using matched sessions, channels, observations, and sigma
grids. Both models use the same five session folds repeated five times and
select sigma by equal-cue CV MSE. It also performs nested CV: each outer fold
selects sigma by five-fold inner CV using only its training sessions, then
fits cue-specific beta on those training sessions and predicts the outer
test sessions. This evaluates both beta fitting and sigma selection.

The primary comparison is the old-minus-new equal-cue outer-fold MSE, using
the Nadeau-Bengio corrected paired t-test to account approximately for
overlapping training sets. Positive differences favor Combined AI. The
output includes a one-sided improvement p-value, two-sided p-value, and 95%
confidence interval; the four secondary cue-wise improvement p-values use
Holm adjustment. Individual repeats/folds are not treated as independent
observations in the standard-error calculation. All comparisons, outer
predictions, inner/outer fold assignments, and selected sigmas are saved in
`<Area>\<UnitType>\ChannelFirstCombinedAI_CVComparison`. Defaults are MT 2D,
five outer repeats, five outer folds, five inner folds, and seed 1.

```matlab
addpath('02_gaussian/interactive_population/channel_prediction');
analysis = RunGaussianChannelCVComparison;
```

The variance correction follows the [documented corrected repeated-CV
comparison](https://scikit-learn.org/stable/auto_examples/model_selection/plot_grid_search_stats.html).
Older one-method launchers are retained under
`interactive_population/legacy_launchers` only for compatibility.

Generated artifacts default to area-specific folders outside the repository:
`C:\EM\CurrentSpread\02_gaussian\InteractiveGaussianMetaPopulation\MT` and
`...\FST`. `BuildInteractiveGaussianMetaPopulationSuite(Area="FST")` builds
the FST cache, the channel-first prediction objective, and all three legacy
meta objectives for both 2D and 3D selections.

The legacy meta CV method maximizes the unweighted sum of four cue-specific repeated
five-fold cross-validated R-squared values. The ordinary method maximizes the
corresponding four full-sample R-squared values. Both use
`DeltaBias ~ AI + AI:OD` without an OD main effect. The distance method
minimizes the unweighted sum of cue-wise mean squared perpendicular distances
to the displayed OD-weighted Type II lines.

Slider movement reads only cached results and does not recalculate tuning or
fits. The population viewer also provides live controls for dot size, marker
edge transparency, marker edge width, and colored versus grayscale dot-face fill.
These are display-only settings and persist when area, population class, or
optimization method is changed within the app.

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
