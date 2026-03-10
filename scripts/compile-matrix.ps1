param(
    [string[]]$Devices = @("epix2", "fenix6", "fr955", "fenix847mm", "fenix8solar51mm"),
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$MonkeyC = "monkeyc",
    [string]$SigningKey = "",
    [switch]$KeepGoing
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$junglePath = Join-Path $ProjectRoot "monkey.jungle"
$outputDir = Join-Path $ProjectRoot "bin\\matrix"
$lowMemoryDevices = @("instinct2", "instinct2s", "instinct2x", "instinctcrossover")

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

$failures = @()
$start = Get-Date

Write-Host "Compile matrix starting..."
Write-Host "Project: $ProjectRoot"
Write-Host "Devices: $($Devices -join ', ')"

foreach ($device in $Devices) {
    $outFile = Join-Path $outputDir ("check-{0}.prg" -f $device)
    $args = @(
        "-f", $junglePath,
        "-d", $device,
        "-o", $outFile,
        "-y", $SigningKey,
        "-w"
    )

    if ($device -in $lowMemoryDevices) {
        $args += @("-O", "2z", "-r")
    }

    Write-Host ""
    Write-Host "==> [$device] compiling..."

    & $MonkeyC @args
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $failures += $device
        Write-Host "==> [$device] FAILED (exit $exitCode)"
        if (-not $KeepGoing) {
            break
        }
    } else {
        Write-Host "==> [$device] OK"
    }
}

$elapsed = (Get-Date) - $start
Write-Host ""
Write-Host "Compile matrix finished in $([math]::Round($elapsed.TotalSeconds, 1))s."

if ($failures.Count -gt 0) {
    Write-Host "Failed targets: $($failures -join ', ')"
    exit 1
}

Write-Host "All targets passed."
exit 0
