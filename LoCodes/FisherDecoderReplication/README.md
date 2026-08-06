# Fisher decoder replication

This folder reproduces the binary Fisher linear-discriminant analysis used
for Figure 5 of Thompson et al. (2023), then repeats it separately for Jim
and Clay. It additionally runs the same decoder on the `2Donly` population,
which has significant monocular direction tuning but no significant
combined-cue direction tuning.

## Run

1. Confirm that
   `C:\LoData\NeuroRespUnitTable.mat` and `C:\LoData\MIDTable.mat`
   exists.
2. Run `run_fisher_decoder_replication.m`.

The runner combines the row-aligned LoData response and metadata tables into
four population inputs under `FisherDecoderInputs`. These cached inputs are
reused on later runs.

The output directory contains pooled, Jim-only, and Clay-only PNG/FIG files
plus `FisherDecoderResults.mat` with bootstrap scores, confidence intervals,
weights, thresholds, configuration, and population sizes.

## Expected inputs

The automatic preparation step reads `NeuroRespUnitTable` from
`NeuroRespUnitTable.mat` and the current `MIDTable` from `MIDTable.mat`.
Their rows are verified using date, ROI, and unit. `NeuroResp` cells contain
condition x coherence x trial/block firing rates; population membership is
rebuilt from the current metadata.

Prepared neural data MAT files contain:

- `firingRates`: neuron x condition x coherence x time x trial.
- `trialNum`: neuron x condition x coherence.

The metadata MAT file must contain `AllMonkeyMIDTable` or `MIDTable`, with
`Monkey`, `ROI`, `sig_Anova_CLR`, `Z_quad`, and `Monocularity_Aligned`.
Within each monkey/area, metadata rows must have the same order as neurons in
the corresponding firing-rate file.

The analysis expects 13 signed coherences with zero at index 7 and at least
four conditions ordered as combined, left perspective, right perspective,
and stereoscopic. After eye-dominance alignment, conditions 2 and 3 become
dominant- and non-dominant-eye perspective.

Dominance is taken directly from `MIDTable.Monocularity_Aligned`: positive
means right-eye dominant. Preparation independently reconstructs its sign
from the left/right response maxima and stops on any disagreement. Run
`diagnose_dominant_eye_alignment` for a per-neuron CSV audit and a post-swap
check that decoder condition 2 is the higher-response eye.

## Reproducibility notes

- Sampling is with replacement and independent across neurons, creating a
  pseudo-population as described in the paper.
- Training uses the combined-cue responses from all nonzero coherences.
- Testing uses held-out responses from every cue and coherence.
- Twenty pseudo-trials, two folds, and 1,000 repetitions match the published
  Methods and original MATLAB scripts.
- A fixed random seed makes an entire run repeatable. Change the seed to
  obtain a new realization of the repeated resampling analysis.
