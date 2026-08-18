# 3DMotionStim MUA tuning extraction

`Extract3DMotionStimTuning.m` extracts 3-D motion tuning from the neural data
recorded during a stimulation experiment. It uses the same event decoding and
firing-rate window as the existing `3DMotionQuick` extractor:

- direction: EID 4000/4002;
- condition: EID 8001 through 8004;
- signed coherence: EID 10000 through 20000;
- response window: first EID 118 through the last EID 130 before trial end;
- firing rate: spike count in that window divided by its duration.

The important difference is trial splitting. In a `3DMotionStim` recording,
EID 222 marks an electrical-stimulation trial. The top-level `Neuro` fields use
only trials without EID 222 so they can replace Quick-derived tuning without
electrical artifacts:

```matlab
[Neuro, TrialSummary, ExtractionSummary] = ...
    Extract3DMotionStimTuning(recordingFolder, ...
    {stimTInfoName, stimSelIndexName});
```

The result keeps the familiar fields `Neuro.Means`, `Neuro.SEM`, `Neuro.All`,
and `Neuro.Trials`, with the same 12 nonzero coherence columns as the Quick
extractor. The same result is also named `Neuro.NoStim`. For auditing,
`Neuro.Stim` contains EID-222 trials and `Neuro.Pooled` contains both groups.
Arrays remain in acquisition-channel order; `Neuro.ChannelMap` records physical
probe order without reordering the response data. `Neuro.TrialFiringRate`
contains the lean trial-by-channel-by-unit response matrix in the same row order
as `TrialSummary`, so time-within-recording drift can be examined without
retaining the very large raw `TrialInfo` structure.

Zero-coherence trials are preserved separately under `Neuro.WithZero`; they
are deliberately absent from the top-level arrays so existing 12-column
consumers cannot silently shift the positive-coherence indices. Direct
comparisons with Quick tuning should use `Neuro.Trials.NumTrials > 0` and
restrict both recordings to their common occupied coherence bins.

## Jim 2024-04-16 example

Run:

```matlab
result = RunExample_Extract3DMotionStimTuning_20240416();
```

The example reads `P:\Jim\NeuroData\20240416` without modifying it. By default,
it saves the compact tuning result, a per-trial inclusion audit, condition/bin
trial counts, and the 16-channel tuning figure under
`C:\EM\FullAnalysisPipeline\outputs\StimTuning_20240416`.

For a read-only run without saved artifacts or a figure:

```matlab
result = RunExample_Extract3DMotionStimTuning_20240416( ...
    MakePlot=false, SaveOutput=false);
```

`ApplyEyeCheck=true` is the default and invokes the same external
version/vergence helper as the Quick pipeline when it is available. Set it to
false to use the TInfo selection mask alone.

## Compare the Stim-period tuning with all Quick channels

`CompareStimTuningToQuickChannels.m` uses the stimulation electrode's tuning
from the **non-electrical-stimulation trials** as a reference. It aligns that
reference with every channel's `unit_table_gof.tuning_mean` on the same
cue/coherence cells. For the Jim 2024-04-16 recording, the shared support is
four cues by these eight coherence values:

```matlab
[-22 -14 -10 -8 8 10 14 22] / 22
```

Each cue is z-scored independently across those eight mean firing rates with
the sample standard deviation. This exactly matches the convention used by
`unit_table_gof.tuning_z`. The channel score is the unweighted sum of squared
differences across all 32 cells. A channel is not ranked if any cell is
missing, so missing data cannot lower its SSE.

Run the tested example with:

```matlab
comparison = RunExample_CompareStimTuningToQuick_20240416();
```

It finds the table row from monkey and recording date rather than relying on a
fixed row number. Outputs under
`C:\EM\FullAnalysisPipeline\outputs\StimVsQuick_20240416` include:

- the complete comparison MAT;
- a channel ranking CSV and a long cell-by-cell audit CSV;
- a physical-order 4-by-4 overlay of all Quick channels;
- a four-cue overlay of the best channel; and
- an SSE ranking plot.

In the overlays, the common Z-scored Stim-period reference is drawn first as a
thick translucent curve; the same-day Quick curve is opaque with circular
markers. The analysis arrays remain indexed by acquisition channel, while the
hard-coded probe map is used only to order plots and report relative position.
