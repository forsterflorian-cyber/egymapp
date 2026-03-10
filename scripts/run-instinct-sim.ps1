param(
    [ValidateSet("instinct2", "instinct2s", "instinct2x", "instinctcrossover")]
    [string]$Device = "instinct2",
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$MonkeyC = "monkeyc",
    [string]$MonkeyDo = "monkeydo",
    [string]$SigningKey = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$junglePath = Join-Path $ProjectRoot "monkey.jungle"
$outputDir = Join-Path $ProjectRoot "bin\\sim"

if (-not (Test-Path $junglePath)) {
    throw "monkey.jungle not found at: $junglePath"
}

if ([string]::IsNullOrWhiteSpace($SigningKey)) {
    if (-not [string]::IsNullOrWhiteSpace($env:CIQ_DEVELOPER_KEY)) {
        $SigningKey = $env:CIQ_DEVELOPER_KEY
    } elseif (Test-Path "C:\\Users\\forst\\developer_key") {
        $SigningKey = "C:\\Users\\forst\\developer_key"
    }
}

if ([string]::IsNullOrWhiteSpace($SigningKey) -or -not (Test-Path $SigningKey)) {
    throw "Developer key not found. Pass -SigningKey or set CIQ_DEVELOPER_KEY."
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

$outFile = Join-Path $outputDir ("run-{0}.prg" -f $Device)
$args = @(
    "-f", $junglePath,
    "-d", $Device,
    "-o", $outFile,
    "-y", $SigningKey,
    "-w",
    "-O", "2z",
    "-r"
)

Write-Host "Compiling low-memory simulator build for $Device..."
& $MonkeyC @args
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Running $outFile on simulator device $Device..."
& $MonkeyDo $outFile $Device
exit $LASTEXITCODE
