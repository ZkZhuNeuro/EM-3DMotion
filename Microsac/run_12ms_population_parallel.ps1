$ErrorActionPreference = 'Stop'

$matlab = 'C:\Program Files\MATLAB\R2025b\bin\matlab.exe'
$codeDir = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\Microsac'
$outputRoot = 'C:\EM\Microsac\population_merged_12ms_no_smoothing'
$logDir = Join-Path $outputRoot 'logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

$chunks = @(
    @{ Rows = '1:64';    Suffix = '_chunk1' },
    @{ Rows = '65:128';  Suffix = '_chunk2' },
    @{ Rows = '129:192'; Suffix = '_chunk3' },
    @{ Rows = '193:254'; Suffix = '_chunk4' }
)

$processes = foreach ($chunk in $chunks) {
    $expression = "addpath('$codeDir'); run_population_microsaccades_12ms_chunk($($chunk.Rows),'$($chunk.Suffix)');"
    $stdout = Join-Path $logDir ($chunk.Suffix.TrimStart('_') + '_stdout.log')
    $stderr = Join-Path $logDir ($chunk.Suffix.TrimStart('_') + '_stderr.log')
    Start-Process -FilePath $matlab -ArgumentList "-batch `"$expression`"" `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr `
        -WindowStyle Hidden -PassThru
}

$processes | Wait-Process
$failed = @($processes | Where-Object { $_.ExitCode -ne 0 })
if ($failed.Count -gt 0) {
    throw "$($failed.Count) MATLAB chunk process(es) failed. Inspect $logDir."
}

$aggregateExpression = "addpath('$codeDir'); run_population_microsaccade_analysis('C:\EM\PopulationAnalysis\UnitTable_updating.mat','OutputRoot','$outputRoot','AggregateSuffix','_complete','SmoothWindowMs',0,'MinDurationMs',12,'RequireBinocular',false,'ComparisonPermutationCount',1000,'SaveEyeTraces',false,'MakeQCPlot',true,'MakeDirectionPlot',true,'MakeExampleTrajectoryPlot',true,'ExampleTrajectoryCountPerCondition',20,'DirectionFigureRoot',fullfile('$outputRoot','figures','session_envelopes'),'ExampleFigureRoot',fullfile('$outputRoot','figures','session_random_trajectories'),'OverwriteExisting',false,'ContinueOnError',true);"
& $matlab -batch $aggregateExpression
if ($LASTEXITCODE -ne 0) {
    throw 'Final 12 ms aggregate rebuild failed.'
}

$postExpression = "addpath('$codeDir'); run(fullfile('$codeDir','run_12ms_population_postprocessing.m'));"
& $matlab -batch $postExpression
if ($LASTEXITCODE -ne 0) {
    throw '12 ms population postprocessing failed.'
}

$marker = Join-Path $outputRoot 'BATCH_COMPLETE.txt'
@"
Completed: $(Get-Date -Format o)
Minimum continuous threshold duration: 12 ms
Position smoothing: none
Sessions requested: 254
See population_microsaccade_session_manifest_complete.csv for status.
"@ | Set-Content -LiteralPath $marker
