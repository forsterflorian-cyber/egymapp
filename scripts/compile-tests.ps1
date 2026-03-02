param(
    [string]$Device = "epix2",
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$MonkeyC = "monkeyc",
    [string]$SigningKey = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$junglePath = Join-Path $ProjectRoot "monkey.jungle"
$outputDir = Join-Path $ProjectRoot "bin\\tests"

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

$outFile = Join-Path $outputDir ("tests-{0}.prg" -f $Device)
$args = @(
    "-f", $junglePath,
    "-d", $Device,
    "-o", $outFile,
    "-y", $SigningKey,
    "-w",
    "-t"
)

Write-Host "Compiling tests for $Device..."
& $MonkeyC @args
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    exit $exitCode
}

Write-Host "Test build successful: $outFile"
exit 0
