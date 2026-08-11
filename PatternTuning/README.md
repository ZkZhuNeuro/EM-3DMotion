# FST pattern-tuning indices

This analysis computes the requested perspective-versus-lateral response metrics for Lo's classified 3D FST population:

```matlab
ROI == "FST" & sig_Anova_CLR & Z_quad == 2
```

`Z_quad == 2` is Lo's complete 1.28 classification, not merely a shorthand for `Z3D_v_Z2D > 1.28`. The original classifier first leaves a unit unclassified when both component-model Z scores are below 1.28; only after that gate does it classify a unit as 3D when the 3D-minus-2D Z-score difference exceeds 1.28. This reproduces the published 58/157 FST count (49 Jim, 9 Clay). Applying the difference cutoff alone incorrectly adds nine `Z_quad == 1` units whose 3D component Z score is below 1.28. The output still retains each unit's continuous `Z3D_v_Z2D` value for auditing.

## Source datasets

The runner uses three aligned population tables:

- `C:\LoData\NeuroRespUnitTable.mat` (`NeuroRespUnitTable`) for trial/block-level 3D responses
- `C:\LoData\LateralMotionRawFRTable.mat` (`LateralMotionRawFRTable`) for independent 2D lateral-motion responses
- `C:\LoData\MIDTable.mat` (`MIDTable`) for unit classification, metadata, and combined-cue preference

It does not use the thin `MotionData_ByStim` table. The requested indices compare the eye-specific perspective cues from the 3D dataset with the separate 2D lateral-tuning dataset.

## Metric mapping

The 3D response tensor is `cue x signed coherence x repeat`. Cue 2 is the left-eye perspective condition, cue 3 is the right-eye perspective condition, coherence `+1` is toward, and coherence `-1` is away:

| Metric | Response |
|---|---|
| `T_L` | left-eye perspective, toward at coherence `+1` |
| `T_R` | right-eye perspective, toward at coherence `+1` |
| `A_L` | left-eye perspective, away at coherence `-1` |
| `A_R` | right-eye perspective, away at coherence `-1` |

For the 2D metrics, the first letter is motion direction and the suffix is eye. Condition 8001 is left eye, 8002 is right eye, 0 degrees is rightward, and 180 degrees is leftward:

| Metric | Response |
|---|---|
| `R_L` | rightward, left eye |
| `R_R` | rightward, right eye |
| `L_L` | leftward, left eye |
| `L_R` | leftward, right eye |

The indices are:

```text
TDI = (T_L + T_R - R_L - L_R) / (T_L + T_R + R_L + L_R)
ADI = (A_L + A_R - L_L - R_R) / (A_L + A_R + L_L + R_R)
```

A zero or nonfinite denominator produces `NaN` and a false validity flag. Means omit nonfinite trials/repeats. Firing rates use the full stimulus interval without baseline subtraction, matching the source pipelines.

## Speed handling

The primary one-row-per-unit result uses event code 7041, the experiment's slow (~4.2 deg/s) 2D condition. This is the appropriate speed match because the 3D signal dots moved at about 4.2 deg/s and the horizontal monocular 2D stimuli at that speed were equivalent to monocular views of the 100%-coherence stereoscopic stimulus. All 58 target units have this condition.

The faster condition (event code 7125, ~12.6 deg/s) is not pooled into the primary indices. It is analyzed separately with the same metrics, preference groups, and tests. It is available for 57 of the 58 target units; source row 362 (Jim, 2019-12-11, tetrode 2, unit 2; away-preferring) has no fast-speed condition. Separate results for every available speed are retained in the by-speed output.

## Toward/away coloring

Preference is defined from the combined-cue asymmetry index already stored in `MIDTable`: `Combined_AI > 0` is toward-preferring, `Combined_AI < 0` is away-preferring, and exactly zero is neutral. Preference only controls the plot color; it does not alter any response metric or index. The CSV/MAT outputs retain both `Combined_AI` and `CombinedCuePreference`. The summary figure overlays semi-transparent, identically binned probability histograms so the unequal-sized preference groups can be compared by distribution shape.

## Run

From MATLAB:

```matlab
cd('C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\PatternTuning')
TestComputeFSTPatternTuningIndices
RunFSTPatternTuningAnalysis
```

Outputs are written to `outputs/`:

- `FST3DPatternTuningIndices.csv`: primary matched-speed result, one row per unit
- `FST3DPatternTuningIndices_Fast.csv`: fast-speed result, one row per unit with that condition
- `FST3DPatternTuningIndices_BySpeed.csv`: one row per unit and available speed
- `FST3DPatternTuningSummary.csv`: overall and per-monkey summaries
- `FST3DPatternTuningZeroTests.csv`: toward/away one-sample tests against zero for both speeds
- `FST3DPatternTuningIndices.mat`: all tables plus analysis configuration
- `FST3DPatternTuningIndices.png`: matched-slow panels on the top row and corresponding fast-speed panels below, using shared axes and histogram bins

The specified TDI/ADI equations require the two eye-specific perspective cues. A combined-cue response cannot be split into `T_L` and `T_R`; no unrequested combined-versus-stereo index is invented here.

## Tests against zero

For each speed, index, and combined-cue preference group, the runner performs a two-sided one-sample Wilcoxon signed-rank test against zero. This is the one-sample counterpart appropriate for a fixed zero null; `ranksum` instead requires two independent samples. Four tests are run within each speed (`TDI/ADI x toward/away`). The output reports raw p-values, Bonferroni adjustment within each four-test speed family, and the more conservative Bonferroni adjustment across all eight slow-plus-fast tests.

## EM `unit_table_gof` analysis

The independent EM implementation reads `C:\EM\PopulationAnalysis\unit_table_gof.mat` and selects the analyzed stimulation-channel units with:

```matlab
ROI == "FST" & ND == "3D"
```

In this table, `ND == "3D"` means that both perspective cues have `p_AI < 0.05` and `Z3D_v_Z2D > 0`. The analyzed channel is `StimElec`. Combined-cue preference is the sign of `AI(1, StimElec)`.

The 3D endpoint metrics come from `tuning_mean`: cue 2/3 and the first/last stored coherence columns for away/toward. The 2D metrics are trial means from `Raw2D_StimCh`, whose axes are direction x speed x eye x repeat. Direction indices 1/5 are 0/180 degrees, speed indices 1/2 are approximately 4.2/12.5 deg/s, and eye indices 1/2 are left/right. The EM table retains trial-level 2D responses but only mean 3D responses, so `N_R_L` through `N_L_R` are reported while the four 3D trial-count fields are `NaN`.

Run the EM analysis from MATLAB:

```matlab
cd('C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\PatternTuning')
TestComputeEMFSTPatternTuningIndices
RunEMFSTPatternTuningAnalysis
```

EM outputs are written to `outputs_em/` with the prefix `EMFST3DPatternTuning`. They include slow, fast, and by-speed CSV tables; a speed-aware summary; signed-rank tests; a MAT file; and the same two-row, three-column comparison figure used for Lo's analysis.

## Combined Lo and EM analysis

`RunCombinedLoEMFSTPatternTuningAnalysis` merges the two datasets without changing either standalone output. For this combined analysis only, Lo's 1.28 classification is relaxed to:

```matlab
ROI == "FST" & sig_Anova_CLR & Z3D_v_Z2D > 0
```

The EM selection remains `ROI == "FST" & ND == "3D"`. The merged table includes `SourceDataset`, the original source row and identifiers, a unified speed rank/label, and all response metrics and indices.

The histogram panels pool Lo and EM units completely and retain only the toward/away color distinction. In scatter panels, color still represents toward/away preference, circles represent Jim, diamonds represent Clay, filled markers represent Lo, and open markers represent EM. Signed-rank tests are performed on the pooled preference groups.

Run from MATLAB:

```matlab
cd('C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\PatternTuning')
RunCombinedLoEMFSTPatternTuningAnalysis
```

Combined outputs are written to `outputs_combined/` with the prefix `CombinedLoEMFST3DPatternTuning`.
