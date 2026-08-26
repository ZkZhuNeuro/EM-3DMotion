# Population analysis with stimulation-task NoStim tuning

Run:

```matlab
RunPopulationAnalysis_StimNoStim_ODweighted
```

Edit `area` (`MT` or `FST`) and `monkey` (`Both`, `Jim`, or `Clay`) at the
top of that script. The result variables and figures match
`RunPopulationAnalysis_ODweighted.m`, with `population_results.tuning_source`
set to `StimNoStim`.

The analysis loads
`C:\EM\StimTuningAnalysis\unit_table_stim.mat` directly as its authoritative
table. It does not load or join the current `unit_table_gof`, and it does not
refresh the cohort from the recording workbooks.
It uses the current stimulation acquisition channel directly (`StimElec`)
from these non-electrical-stimulation fields:

- `stim_tuning_mean_noStim`;
- `stim_tuning_SEM_noStim`;
- `stim_tuning_n_noStim`; and
- `stim_tuning_coherence`.

AI follows the original 3DMotionQuick definition. Zero coherence is excluded,
all six matched away/toward coherence pairs are used, and sample SD is
reconstructed as `SEM .* sqrt(N)`. Signed OD is
`(max(MonoL)-max(MonoR))/(max(MonoL)+max(MonoR))` over the nonzero
coherences supported by Combined-cue trials. The two eye maxima independently
omit missing responses, matching the legacy calculation; positive OD means
left-eye dominant.

Only AI and OD are recalculated. The neural significance gate (`p_AI`), the
`Z3D_v_Z2D` 2D/3D label, behavioral fits, and recording metadata are read from
the inherited columns stored in `unit_table_stim`. Selection rules, regression
models, and plotting conventions remain those of the original analysis.
The result contains `stim_noStim_index_audit` for row-level provenance.
It also contains `stim_table_load_audit`, which records every original artifact
row, its tuning status, and whether it entered the population. Included rows
retain their original index in `stim_tuning_artifact_table_row`.

Only rows whose `stim_tuning_status` begins with `Success` are used. Pending or
failed rows are excluded with a warning and remain visible in the load audit;
the loader errors if the artifact contains no completed rows.

Synthetic tests:

```matlab
results = runtests({ ...
    'TestCalculateStimNoStimAIOD.m', ...
    'TestGetPopulationAIOD.m', ...
    'TestLoadUnitTableStimForPopulation.m', ...
    'TestPrepareStimNoStimPopulationAIOD.m'});
assertSuccess(results)
```
