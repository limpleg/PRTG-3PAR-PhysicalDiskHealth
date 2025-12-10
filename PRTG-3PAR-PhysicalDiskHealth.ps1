
<#
.SYNOPSIS
  PRTG EXE/Script Advanced sensor for HPE 3PAR physical disk health (failed/degraded).

.PARAMETER Host
  3PAR array hostname or IP.

.PARAMETER User
  SSH username on the 3PAR.

.PARAMETER Password
  SSH password (optional if using key auth). For PRTG, pass this as parameter or store via credentials.

.PARAMETER KeyFile
  Path to private key (optional). If set, password is ignored.

.PARAMETER Transport
  'PoshSSH' (default) or 'Plink'. Choose 'Plink' if Posh-SSH is not available.

.PARAMETER PlinkPath
  Path to plink.exe (only needed if Transport = 'Plink' and plink is not in PATH).

.PARAMETER TimeoutSec
  SSH command timeout in seconds. Default 30.

.OUTPUTS
  PRTG XML for EXE/Script Advanced.

.EXAMPLES
  PowerShell:
    .\PRTG-3PAR-PhysicalDiskHealth.ps1 -Host 3par01 -User monitor -Password "********"

  With key & plink:
    .\PRTG-3PAR-PhysicalDiskHealth.ps1 -Host 3par01 -User monitor -KeyFile "C:\keys\3par.ppk" -Transport Plink -PlinkPath "C:\Tools\plink.exe"
#>


<#
.SYNOPSIS
  PRTG EXE/Script Advanced sensor für HPE 3PAR Physical Disk Health (failed/degraded).
#>

param(
  [Parameter(Mandatory=$true)] [string]$TargetHost,
  [Parameter(Mandatory=$true)] [string]$User,
  [Parameter(Mandatory=$true)] [string]$Password,
  [Parameter(Mandatory=$true)] [string]$HostKey, # Fingerprint für automatisches Vertrauen
  [string]$PlinkPath = "C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\plink.exe",
  [int]$TimeoutSec = 30
)

function Write-PrtgXml {
  param([int]$FailedCount,[int]$DegradedCount,[string]$Text,[bool]$IsError=$false)

$warningFlag = if ($DegradedCount -gt 0) {1}else{0}
$errorFlag = if (($FailedCount -gt 0) -or $IsError) {1}else{0}

  @"
<prtg>
  <result>
    <channel>Failed Physical Disks</channel>
    <value>$FailedCount</value>
    <unit>Count</unit>
  </result>
  <result>
    <channel>Degraded Physical Disks</channel>
    <value>$DegradedCount</value>
    <unit>Count</unit>
  </result>
  <text>$Text</text>
  <warning>$warningFlag</warning>
  <error>$errorFlag</error>
</prtg>
"@
}

function Invoke-PlinkCommand {
  param([string]$Command)
  $args = @("-batch","-pw",$Password,"-hostkey",$HostKey,"$User@$TargetHost",$Command)
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $PlinkPath
  $psi.Arguments = ($args -join " ")
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  $p.Start() | Out-Null
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  if (-not $p.WaitForExit($TimeoutSec*1000)) {try{$p.Kill()}catch{};throw "Timeout"}
  if ($p.ExitCode -ne 0){throw "Plink error: $stderr"}
  return $stdout
}

try {
  # SSH-Befehle ausführen
  $failedOut = Invoke-PlinkCommand "showpd -failed"
  $degradedOut = Invoke-PlinkCommand "showpd -degraded"

  # ANSI-Steuerzeichen entfernen
  $failedOut = ($failedOut -replace '\x1B\[[0-9;]*[A-Za-z]', '')
  $degradedOut = ($degradedOut -replace '\x1B\[[0-9;]*[A-Za-z]', '')

  # Failed zählen
  $failedLines = ($failedOut -split "`r?`n" | Where-Object {$_ -match '^\s*\d+' -and $_ -match 'failed'})
  $failedCount = $failedLines.Count
  $failedIDs = ($failedLines | ForEach-Object {($_ -split '\s+')[0]}) -join ", "
  if ([string]::IsNullOrWhiteSpace($failedIDs)) {$failedIDs = "none"}

  # Degraded zählen
  $degradedLines = ($degradedOut -split "`r?`n" | Where-Object {$_ -match '^\s*\d+' -and $_ -match 'degrad'})
  $degradedCount = $degradedLines.Count
  $degradedIDs = ($degradedLines | ForEach-Object {($_ -split '\s+')[0]}) -join ", "
  if ([string]::IsNullOrWhiteSpace($degradedIDs)) {$degradedIDs = "none"}

  # Fallback auf showpd -state, falls degraded leer
  if ($degradedCount -eq 0) {
    $stateOut = Invoke-PlinkCommand "showpd -state"
    $stateOut = ($stateOut -replace '\x1B\[[0-9;]*[A-Za-z]', '')
    $degradedLines = ($stateOut -split "`r?`n" | Where-Object {$_ -match '^\s*\d+' -and $_ -match 'degrad'})
    $degradedCount = $degradedLines.Count
    $degradedIDs = ($degradedLines | ForEach-Object {($_ -split '\s+')[0]}) -join ", "
    if ([string]::IsNullOrWhiteSpace($degradedIDs)) {$degradedIDs = "none"}
  }

  # Zusammenfassung
  $summary = "3PAR PD health: Failed=$failedCount (IDs: $failedIDs), Degraded=$degradedCount (IDs: $degradedIDs)"
  Write-PrtgXml -FailedCount $failedCount -DegradedCount $degradedCount -Text $summary
} catch {
  Write-PrtgXml -FailedCount 0 -DegradedCount 0 -Text "Error: $($_.Exception.Message)" -IsError:$true
}
