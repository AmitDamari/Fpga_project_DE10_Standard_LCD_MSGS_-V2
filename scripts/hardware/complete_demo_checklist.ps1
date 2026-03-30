param(
    [string]$Operator = "",
    [string]$Board = "",
    [string]$Bitstream = "",
    [string]$HpsAppBuild = "",
    [switch]$CompleteBoardItems
)

$ErrorActionPreference = "Stop"

$path = ".\\artifacts\\hardware\\demo_checklist_log.md"
if (-not (Test-Path $path)) {
    Write-Error "Checklist log not found: $path"
}

$content = Get-Content $path -Raw

function Upsert-HeaderLine {
    param(
        [string]$Text,
        [string]$Key,
        [string]$Value
    )

    $line = ("{0}: {1}" -f $Key, $Value)
    if ($Text -match ("(?m)^" + [regex]::Escape($Key) + ":")) {
        return ($Text -replace ("(?m)^" + [regex]::Escape($Key) + ":.*$"), $line)
    }

    # Insert missing key after Date/Operator/Board/Bitstream/HPS block if absent.
    if ($Text -match "(?m)^# Demo Checklist Log\r?\n\r?\n") {
        return ($Text -replace "(?m)^# Demo Checklist Log\r?\n\r?\n", ("# Demo Checklist Log`r`n`r`n" + $line + "`r`n"))
    }

    return ($line + "`r`n" + $Text)
}

$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$content = Upsert-HeaderLine -Text $content -Key "Date" -Value $now

if ($Operator -ne "") { $content = Upsert-HeaderLine -Text $content -Key "Operator" -Value $Operator }
if ($Board -ne "") { $content = Upsert-HeaderLine -Text $content -Key "Board" -Value $Board }
if ($Bitstream -ne "") { $content = Upsert-HeaderLine -Text $content -Key "Bitstream" -Value $Bitstream }
if ($HpsAppBuild -ne "") { $content = Upsert-HeaderLine -Text $content -Key "HPS App Build" -Value $HpsAppBuild }

if ($CompleteBoardItems) {
    $content = $content -replace "- \[ \] FPGA programmed successfully", "- [x] FPGA programmed successfully"
    $content = $content -replace "- \[ \] HPS app launched successfully", "- [x] HPS app launched successfully"
    $content = $content -replace "- \[ \] IDLE screen visible", "- [x] IDLE screen visible"
    $content = $content -replace "- \[ \] IDLE -> HOME transition confirmed", "- [x] IDLE -> HOME transition confirmed"
    $content = $content -replace "- \[ \] HOME -> MSG transition confirmed", "- [x] HOME -> MSG transition confirmed"
    $content = $content -replace "- \[ \] MSG next/previous navigation confirmed", "- [x] MSG next/previous navigation confirmed"
    $content = $content -replace "- \[ \] KEY0 back navigation confirmed", "- [x] KEY0 back navigation confirmed"
    $content = $content -replace "- \[ \] Timeout -> SLEEP confirmed", "- [x] Timeout -> SLEEP confirmed"
    $content = $content -replace "- \[ \] Wake from SLEEP confirmed", "- [x] Wake from SLEEP confirmed"
}

Set-Content -Path $path -Value $content -Encoding ASCII
Write-Host ("Updated checklist log: {0}" -f $path) -ForegroundColor Green
