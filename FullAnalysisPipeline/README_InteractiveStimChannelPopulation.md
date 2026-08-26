# Interactive stimulation-channel population plots

Run:

```matlab
app = ExploreInteractiveStimChannelPopulation;
```

This opens the current MT 2D, MT 3D, FST 2D, and FST 3D population figures.
Click a population dot to open that session's three-panel tuning and behavior
plot (stimulation-channel neural tuning, NoStim behavior, and Stim behavior).
Data tips also report the session, condition, stimulation electrode, AI,
Delta bias, and absolute OD.

The viewer uses this population table by default:

```text
C:\EM\StimChannelAnalysis\unit_table_gof_uniform_temp.mat
```

The population readout remains the original stimulation acquisition channel:

- AI and OD use the original stimulation acquisition channel's 3DMotionQuick
  tuning, not a best channel or a Gaussian/meta-channel readout;
- the current workbook selection, neural significance filters, 2D/3D labels,
  behavior fits, cue colors, monkey markers, OD opacity, and OD-weighted
  through-origin regression lines come from the current population pipeline;
- click-through panels are resolved through
  `C:\EM\allSessions\allSessions_manifest.csv`.

To intentionally restore the old recursive newest-artifact behavior, pass an
empty `DataFile`:

```matlab
app = ExploreInteractiveStimChannelPopulation(DataFile="");
```

The returned `app` structure contains the selected `DataFile`, all four figure
handles, the MT and FST population results, and `AttachmentAudit`. Any point
without a matching session PNG appears in `app.UnmatchedPoints` and produces a
warning when clicked.

For a non-visible validation run:

```matlab
app = ExploreInteractiveStimChannelPopulation(Visible="off");
assert(isempty(app.UnmatchedPoints))
close(app.Figures)
```
