param([ValidateSet('functional','security','all')][string]$Suite = 'all')
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportDir = Join-Path $root 'evidencias/reportes'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$log = Join-Path $reportDir "ejecucion_${Suite}_${stamp}.log"
$targets = switch ($Suite) {
  'functional' { @('test/functional','test/unit') }
  'security' { @('test/security') }
  default { @('test') }
}
& flutter test @targets 2>&1 | Tee-Object -FilePath $log
$code = $LASTEXITCODE
"Exit code: $code`nSuite: $Suite`nLog: $log" | Add-Content -Path $log
exit $code
