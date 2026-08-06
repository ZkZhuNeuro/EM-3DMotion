# Microsaccade analysis

This folder contains MATLAB workflows for single-session and population-level
microsaccade analysis of the 3D-motion electrical-stimulation data.

## Run

From MATLAB, change to this folder and run:

```matlab
run_example_microsaccade_analysis
```

The script reads:

- `C:\EM\Microsac\Clay_FST_17Feb2026_3DMotionStim_MUA_TInfo.mat`
- `C:\EM\Microsac\Clay_FST_17Feb2026_3DMotionStim_MUA_SelIndex.mat`

Outputs are written to `results_engbert`:

- `*_trials.csv`: one row per selected/good trial, including stimulation status and event counts
- `*_events.csv`: one row per binocular microsaccade
- `*_summary.csv`: stimulation versus non-stimulation group summary
- `*_direction_stats.csv`: Rayleigh tests, mean directions, and vector sums
- `*_stim_nonstim_tests.csv`: trial-stratified permutation comparisons
- `*.mat`: all tables, parameters, thresholds, and smoothed eye traces
- `*_qc.png`: example traces and group-level event-count checks
- `*_direction_envelope.png`: all event endpoints, directional amplitude envelopes, and vector sums
- `*_example_trajectories.png`: five NonStim and five Stim trajectories centered at event onset

## Current detection choices

- `EditSel` defines good trials, with `Selected` used as a fallback.
- Event code `222` identifies electrical-stimulation trials.
- Detection is limited to the visual stimulus interval from EID `118` to EID `130`, before the instructed choice saccade.
- Eye positions are treated as screen millimeters and converted to visual degrees with `Config.ScrDistmm`.
- Both eyes are smoothed with a 5 ms moving mean.
- Velocity uses the Engbert-style five-point central derivative.
- Following Engbert and Kliegl (2003), robust horizontal and vertical velocity thresholds are estimated independently for every eye in every trial with `lambda = 6`.
- Monocular candidates must exceed the 2D velocity ellipse continuously for at least 12 ms, matching the original three samples at 250 Hz. There is no amplitude, maximum-duration, merge-gap, onset-lag, or interocular-direction gate by default.
- Following the original binocular criterion, a reported microsaccade requires temporal overlap between left- and right-eye candidates.
- Directional bias is tested with an event-level Rayleigh test. A sensitivity result applies the same test to one circular-mean direction per trial.
- The directional plot shows every mean binocular displacement endpoint. Its envelope is the 95th amplitude percentile in each of 24 direction bins. The plotted arrow is the raw displacement vector sum divided by the number of events; the unscaled sum is stored in `DirectionStatsTable`.

The Rayleigh null hypothesis is a uniform circular distribution. `MeanResultantLength` ranges from 0 (directions cancel) to 1 (all events point identically). The test is designed for a single preferred direction; an axial or two-lobed distribution with equally strong opposite directions can cancel and should also be assessed from the envelope or with an axial test.

Stim versus NonStim differences are tested with 1,000 two-sided trial-level permutations. Stimulation labels are shuffled within each visual-condition and signed-coherence stratum. The tested outcomes are microsaccade rate, probability of any microsaccade, per-trial mean amplitude, peak velocity, duration, and the two-dimensional first circular moment of direction. Event properties are summarized within trials before testing so trials with many events do not act as independent replicates.

All detection parameters are name-value options to `analyze_microsaccades` and are recorded in the output MAT file.

## Population analysis

`run_population_microsaccade_analysis` reads `unit_table`, resolves the
`3DMotionStim` TInfo/SelIndex pair within every session's `Paths` folder, and
runs the same detector once per session. Run the one-session smoke test with:

```matlab
run_population_microsaccade_smoke_test
```

Run all sessions after checking the smoke-test manifest and figures:

```matlab
BatchResults = run_population_microsaccade_analysis( ...
    'C:\EM\PopulationAnalysis\UnitTable_updating.mat', ...
    'SmoothWindowMs', 0, ...
    'MinDurationMs', 6, ...
    'RequireBinocular', false);
```

Population outputs default to `population_results`. Each recording has its own
subfolder. The root folder contains a checkpointed session manifest and combined
summary, direction-statistics, and Stim/NonStim permutation-test CSV files. The
runner loads existing session MAT files by default, so rerunning the command
resumes the batch. Set `'OverwriteExisting', true` to recompute them.

The population runner uses 1,000 permutations by default. The command above uses
the current sensitivity settings: no additional smoothing, a 6 ms minimum
duration, and no binocular pairing. It saves tables and figures but not the large
per-sample eye traces by default.

With `RequireBinocular = false`, temporally connected left- and right-eye
candidates are merged into one event spanning their complete union interval.
Candidates without an overlapping event in the other eye are retained. The event
table labels rows as `DetectionSource = Merged`, `Left`, or `Right`. Set
`RequireBinocular = true` to keep only one-to-one temporally overlapping events.

## Trial-level microsaccade prediction of choice

`analyze_trialwise_ms_choice` replaces the session-mean correlation with a
within-session choice analysis. It verifies that each saved session used a 12 ms
minimum duration, no smoothing, and the merged/unmatched-eye detector used by
`run_population_microsaccades_12ms_chunk`. It then keeps trials containing at
least one microsaccade and averages event displacement vectors within trial.

Run the completed 12 ms population analysis with:

```matlab
run_12ms_trialwise_ms_choice
```

For each session, both an unadjusted and a stimulus-adjusted binomial model are
fit to exactly the same MS-containing trials:

```text
Choice ~ MeanMSY_Z * StimCondition

Choice ~ SignedCoherence * VisualCondition + StimCondition ...
    + MeanMSY_Z * StimCondition
```

`MeanMSY_Z` is the trial's mean vertical microsaccade displacement, standardized
within session. The model controls for signed motion evidence, cue/visual
condition, and stimulation. Its `MeanMSY_Z:StimCondition` coefficient directly
tests whether stimulation changes the trial-level MS effect on choice. A second
model includes both standardized horizontal and vertical displacement and gives a
joint two-dimensional interaction test. The logistic fits use Jeffreys-prior
bias reduction so sparse cue/choice cells do not produce infinite estimates.
The session summary reports a joint test of all added MS coefficients (whether MS
predicts choice in either stimulation condition), condition-specific MS slopes,
and the MS-by-stimulation interaction test for both models. A dedicated model
comparison figure shows how stimulus adjustment changes the slopes and interaction
evidence.

Outputs under `population_analysis/trialwise_ms_choice` include one row per
MS-containing trial, one inferential summary row per session, all model
coefficients, a summary figure, and a MAT file containing the fitted models. The
session-summary CSV also contains Holm-Bonferroni adjusted p-values across
sessions for each model/test family.

## Grouped monkey-by-area choice analysis

`analyze_grouped_ms_choice` pools trials into Jim-MT, Jim-FST, Clay-MT, and
Clay-FST. Run it after the trialwise analysis with:

```matlab
run_grouped_monkey_roi_ms_choice
```

MS displacement is re-standardized within recording session before pooling.
Both the simple and stimulus-adjusted models include session-specific NonStim and
Stim intercepts, preventing differences in baseline choice behavior across
recording days from acting as a pooled MS effect. The adjusted grouped model is:

```text
Choice ~ SessionID * StimCondition ...
    + SignedCoherence * VisualCondition ...
    + MeanMSY_Z * StimCondition
```

A two-dimensional X/Y sensitivity model is also fit. Holm-Bonferroni correction
is performed across the four monkey/area groups separately for each model/test
family. Group summaries, coefficient tables, fitted model objects, and a summary
figure are written under `population_analysis/grouped_monkey_roi_ms_choice`.
The grouped runner also exports highly transparent Stim/NonStim scatter plots of
the simple-model `MeanMSY_Z` predictor versus binary choice. Small deterministic
vertical jitter is used only to reveal density at Choice 0 and Choice 1; it does
not alter the model or saved trial values.
For a binomial response, the more interpretable probability figures from
`plot_grouped_ms_choice_probability` show quantile-binned observed choice
probabilities with Wilson 95% intervals, session-stratified fitted Stim/NonStim
curves, and 95% confidence-interval plots for average MS slopes and
MS-by-Stim interactions.

The runner also fits the exact unstratified pooled logistic model requested for
each monkey/area group:

```text
Choice ~ MeanMSY_Z * StimCondition
```

This analysis is also available by itself through
`run_pooled_logistic_ms_choice`. It exports observed and fitted choice-
probability curves, slopes and odds ratios with 95% intervals, Holm-Bonferroni
tests across the four groups, and a direct comparison with the
session-stratified simple model under
`grouped_monkey_roi_ms_choice/pooled_logistic`. `MeanMSY_Z` remains
standardized within recording session, so its coefficient is the change in log
choice odds per one within-session SD of vertical MS displacement.

The exact pooled model omits `SessionID` and therefore treats every trial row as
independent. Independent recording sessions do not imply independence of trials
within a session. The session-stratified model is retained as the more
conservative comparison because it prevents session-to-session differences in
baseline choice behavior from being attributed to MS_y.

## Method reference

The velocity ellipse, robust median-based threshold, and binocular-overlap approach follow Engbert and Kliegl (2003), [Microsaccades uncover the orientation of covert attention](https://doi.org/10.1016/S0042-6989(03)00084-1).
