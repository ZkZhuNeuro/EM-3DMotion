# Strict PDI/BODI analyses

This folder contains the source code for the strict FST3D, MT2D, and FST2D analyses. Generated results and figures are written outside GitHub to:

```text
C:\EM\PatternTuning\Final_128
```

Each population analysis produces separate Lo, EM, and combined results. Both datasets use the strict 1.28 classification criteria.

## FST3D selection criteria

Lo uses its complete 1.28 classifier:

```matlab
ROI == "FST" & sig_Anova_CLR & Z_quad == 2
```

This selects 58 neurons. `Z_quad == 2` includes the original component-score gate and is not equivalent to applying only `Z3D_v_Z2D > 1.28`.

EM uses the closest strict analogue supported by `unit_table_gof`:

```matlab
ROI == "FST" & ND == "3D" & Z3D_v_Z2D > 1.28
```

This selects 24 neurons. The combined sample therefore contains 82 neurons.

## MT2D and FST2D selection criteria

Lo uses the complete 1.28 2D classifier for each target ROI:

```matlab
ROI == targetROI & sig_Anova_CLR & Z_quad == 4
```

This selects 80 MT2D and 66 FST2D neurons. Fourteen Lo MT2D neurons do not have the matched 7041 lateral-motion speed; they remain in the selected population with valid BODI, while PDI and its components are `NaN` and `Valid_PDI` is false.

EM uses the closest strict 2D analogue supported by `unit_table_gof`:

```matlab
ROI == targetROI & ND == "2D" & Z3D_v_Z2D < -1.28
```

This selects 49 MT2D and 47 FST2D neurons. The combined populations contain 129 MT2D and 113 FST2D neurons.

## Metrics

The 3D response tensor is `cue x signed coherence x repeat`. Cue 1 is combined optic flow, cue 2 is the left-eye perspective condition, cue 3 is the right-eye perspective condition, cue 4 is stereoscopic, coherence `+1` is toward, and coherence `-1` is away.

For the independent 2D data, `R_L`, `R_R`, `L_L`, and `L_R` denote rightward/leftward motion shown to the left/right eye. PDI uses the matched slow 2D speed of about 4.2 deg/s.

```text
TDI = (T_L + T_R - R_L - L_R) / (T_L + T_R + R_L + L_R)
ADI = (A_L + A_R - L_L - R_R) / (A_L + A_R + L_L + R_R)

PDI = TDI for a toward-preferring neuron
PDI = ADI for an away-preferring neuron

BODI = (Combined_FR - Stereo_FR) / (Combined_FR + Stereo_FR)
```

Combined-cue preference is the sign of `Combined_AI`. For BODI, `Combined_FR` and `Stereo_FR` come only from cue 1 and cue 4 at coherence `+1` for toward preference or `-1` for away preference. BODI has no 2D-tuning or speed component; “2D” and “3D” identify the neuron classification, not the stimulus used for BODI.

A zero or nonfinite denominator produces `NaN` and a false validity flag. Means omit nonfinite trials or repeats.

## Statistical analysis and figures

PDI and BODI are pooled across toward- and away-preferring neurons in every dataset. The final figure contains only two probability histograms: PDI and BODI. Preference is not represented by separate colors, groups, or legends.

Each pooled distribution is tested against an equal-sized zero reference using a two-sided Wilcoxon rank-sum test. Bonferroni correction is applied across the two metrics within each dataset.

## Run

From MATLAB:

```matlab
cd('C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\PatternTuning')
TestBuildFSTPDIAndBODITable
RunFSTPDIAndBODIAnalysis128
Run2DPDIAndBODIAnalysis128
```

For the paper-ready Lo-versus-EM FST3D comparison, run:

```matlab
TestBuildFSTDatasetComparisonStatistics
RunFSTPDIAndBODIPaperComparison128
```

The paper runner rebuilds the strict Lo (n = 58), EM (n = 24), and combined
(n = 82) results, verifies all counts, means, medians, and Bonferroni-adjusted
zero-test p values against the rounded Aug 12, 2026 summary, and stops on any
failed check. It then writes `Final_128\PaperComparison` with:

- a wide companion statistics CSV containing selected and valid sample counts,
  mean/SD/SEM/95% CI, median/IQR, EM-minus-Lo mean and median differences,
  Hedges' g, Cliff's delta with a seeded bootstrap 95% CI, and a two-sided
  rank-sum comparison corrected across PDI and BODI;
- a machine-readable Aug 12 verification CSV;
- a MAT file with source tables, configuration, bootstrap seed, and results;
- a 600-dpi PNG plus vector PDF and SVG versions of the comparison figure.

Effect-size signs are always EM minus Lo. The figure uses both color and marker
shape to distinguish datasets and shows every neuron, median/IQR, and mean/95% CI.

Outputs are organized as:

```text
C:\EM\PatternTuning\Final_128\Lo
C:\EM\PatternTuning\Final_128\EM
C:\EM\PatternTuning\Final_128\Combined
C:\EM\PatternTuning\Final_128\MT2D\Lo
C:\EM\PatternTuning\Final_128\MT2D\EM
C:\EM\PatternTuning\Final_128\MT2D\Combined
C:\EM\PatternTuning\Final_128\FST2D\Lo
C:\EM\PatternTuning\Final_128\FST2D\EM
C:\EM\PatternTuning\Final_128\FST2D\Combined
```

Each directory contains:

- the neuron-level PDI/BODI CSV;
- a grouped summary CSV;
- a PDI/BODI rank-sum test CSV;
- a MAT file containing the tables and analysis configuration;
- a PNG with the pooled PDI and BODI histograms.

The existing concise FST3D Word summary is saved at:

```text
C:\EM\PatternTuning\PatternTuning_Analysis_Summary.docx
```

Previous TDI/ADI deliverables are retained under `C:\EM\PatternTuning\Archive\Previous_TDI_ADI_Results` for traceability and are not part of the final result set.

## FST3D population results

| Dataset | n | PDI mean | PDI median | PDI Bonferroni p | BODI mean | BODI median | BODI Bonferroni p |
|---|---:|---:|---:|---:|---:|---:|---:|
| Lo | 58 | 0.154 | 0.185 | 8.76e-08 | 0.140 | 0.127 | 1.54e-11 |
| EM | 24 | 0.202 | 0.209 | 2.60e-07 | 0.178 | 0.191 | 4.07e-06 |
| Combined | 82 | 0.168 | 0.197 | 1.34e-13 | 0.151 | 0.148 | 1.27e-16 |

## MT2D and FST2D population results

| Population | Dataset | selected n | valid PDI n | PDI mean | PDI median | PDI Bonferroni p | valid BODI n | BODI mean | BODI median | BODI Bonferroni p |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| MT2D | Lo | 80 | 66 | 0.096 | 0.077 | 1.52e-08 | 80 | 0.035 | 0.017 | 7.07e-03 |
| MT2D | EM | 49 | 49 | 0.044 | 0.039 | 3.80e-05 | 49 | 0.082 | 0.078 | 6.69e-06 |
| MT2D | Combined | 129 | 115 | 0.074 | 0.056 | 1.33e-12 | 129 | 0.053 | 0.031 | 4.52e-07 |
| FST2D | Lo | 66 | 66 | 0.133 | 0.124 | 3.09e-13 | 66 | 0.151 | 0.156 | 2.63e-14 |
| FST2D | EM | 47 | 47 | 0.033 | 0.031 | 1.35e-04 | 47 | 0.082 | 0.077 | 2.54e-05 |
| FST2D | Combined | 113 | 113 | 0.091 | 0.091 | 3.65e-16 | 113 | 0.122 | 0.132 | 5.34e-18 |
