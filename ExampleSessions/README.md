# Example-session tuning and behavior plots

`PlotExampleSessions.m` makes a three-panel figure for each selected session:

1. neural tuning at the stimulating electrode (mean +/- SEM),
2. psychometric behavior on non-stimulation trials, and
3. psychometric behavior on stimulation trials.

The default input is the same P-drive source used by
`P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\FullStimulationAnalysisPipeline_042022.m`:

- session metadata: `P:\Jim\NeuroData\RecordingRecord_Stimulation_20240515.xlsx`
- analyzed session caches: `P:\Jim\StimData\YYYYMMDD.mat`

The cache files contain `Neuro` and `BehaviorData`; the workbook supplies
the date, ROI, and stimulation electrode.

## Quick use

Run:

```matlab
run_example_session_plots
```

By default, the script plots session index 2, matching the `for rec = 2`
selection in the P-drive pipeline. Edit `exampleSessionIndices` in the runner
to select additional workbook sessions. PNG, PDF, and
`ExampleSessionPlots_manifest.csv` files are written under
`C:\EM\ExampleSessionPlots`.

To export a review PNG for every eligible Jim and Clay session, run:

```matlab
run_all_session_plots
```

The all-session batch reads the final workbooks, uses the local caches under
`C:\Jim\StimData` and `C:\Clay\StimData`, and writes the plots plus a
resumable status manifest to `C:\EM\allSessions`.

To plot a combined analysis MAT file from the newer repository pipeline:

```matlab
manifest = PlotExampleSessions( ...
    "C:\EM\MIDTable_MUAStim_JimClay_Analysis.mat", ...
    SessionIndices=[3 18 27], ...
    OutputDirectory="C:\EM\ExampleSessionPlots", ...
    Formats=["png" "pdf"]);
```

If `SessionIndices` is omitted, rows marked `Success` in
`MIDTable.AnalysisStatus` are used. If the table has no status column, all
sessions with complete plot data are used.

To plot one P-drive session cache directly, supply its metadata:

```matlab
PlotExampleSessions("P:\Jim\StimData\20210721.mat", ...
    StimElectrode=4, Monkey="Jim", ROI="MT", ...
    SessionDate=datetime(2021,7,21));
```
