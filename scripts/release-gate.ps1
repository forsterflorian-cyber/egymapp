param(
    [string[]]$Devices = @("epix2", "fenix5plus", "fenix6", "fr945", "fr955", "fr970", "marq2", "fenix847mm", "fenix8solar51mm", "venusq2"),
    [string]$TestDevice = "epix2",
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$MonkeyC = "monkeyc",
    [string]$SigningKey = "",
    [switch]$SkipTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$junglePath = Join-Path $ProjectRoot "monkey.jungle"
$outputDir = Join-Path $ProjectRoot "bin\\release-gate"

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

$monkeycPath = (Get-Command $MonkeyC -ErrorAction Stop).Source
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

function IsAllowedWarning([string]$line) {
    return (($line -imatch "launcher icon") -and ($line -imatch "scaled to the target size"))
}

function Invoke-CompileStep(
    [string]$label,
    [string[]]$cliArgs,
    [string]$monkeycExec
) {
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $lines = @(& $monkeycExec @cliArgs 2>&1 | ForEach-Object { $_.ToString() })
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }

    $exitCode = $LASTEXITCODE
    foreach ($line in $lines) { Write-Host $line }

    $warnings = @($lines | Where-Object { $_ -like "WARNING:*" })
    $disallowedWarnings = @()
    foreach ($warning in $warnings) {
        if (-not (IsAllowedWarning $warning)) {
            $disallowedWarnings += $warning
        }
    }

    return @{
        Label = $label;
        ExitCode = $exitCode;
        Warnings = $warnings;
        DisallowedWarnings = $disallowedWarnings;
    }
}

$failedSteps = @()
$unexpectedWarnings = @()
$start = Get-Date

Write-Host "Release gate starting..."
Write-Host "Project: $ProjectRoot"
Write-Host "Targets: $($Devices -join ', ')"
Write-Host "Tests: $([string]::Format('{0}', (-not $SkipTests))) on $TestDevice"

foreach ($device in $Devices) {
    Write-Host ""
    Write-Host "==> [build:$device] compiling..."

    $outFile = Join-Path $outputDir ("build-{0}.prg" -f $device)
    $args = @(
        "-f", $junglePath,
        "-d", $device,
        "-o", $outFile,
        "-y", $SigningKey,
        "-w"
    )

    $result = Invoke-CompileStep -label ("build-" + $device) -cliArgs $args -monkeycExec $monkeycPath
    if ($result.ExitCode -ne 0) {
        $failedSteps += "build:$device"
    }
    foreach ($warning in $result.DisallowedWarnings) {
        $unexpectedWarnings += "[build:$device] $warning"
    }
}

if (-not $SkipTests) {
    Write-Host ""
    Write-Host "==> [tests:$TestDevice] compiling..."

    $testOutFile = Join-Path $outputDir ("tests-{0}.prg" -f $TestDevice)
    $testArgs = @(
        "-f", $junglePath,
        "-d", $TestDevice,
        "-o", $testOutFile,
        "-y", $SigningKey,
        "-w",
        "-t"
    )

    $testResult = Invoke-CompileStep -label ("tests-" + $TestDevice) -cliArgs $testArgs -monkeycExec $monkeycPath
    if ($testResult.ExitCode -ne 0) {
        $failedSteps += "tests:$TestDevice"
    }
    foreach ($warning in $testResult.DisallowedWarnings) {
        $unexpectedWarnings += "[tests:$TestDevice] $warning"
    }
}

$elapsed = (Get-Date) - $start
Write-Host ""
Write-Host "Release gate finished in $([math]::Round($elapsed.TotalSeconds, 1))s."

if ($failedSteps.Count -gt 0) {
    Write-Host "FAILED steps: $($failedSteps -join ', ')"
}

if ($unexpectedWarnings.Count -gt 0) {
    Write-Host "Unexpected warnings:"
    foreach ($w in $unexpectedWarnings) {
        Write-Host "  $w"
    }
}

if ($failedSteps.Count -gt 0 -or $unexpectedWarnings.Count -gt 0) {
    exit 1
}

Write-Host "Release gate passed (only allowed warnings present)."
exit 0

