# Start a component:  powershell -ExecutionPolicy Bypass -File scripts\windows\run.ps1 api|bot|selftest
param([ValidateSet("api", "bot", "selftest")][string]$What = "selftest")
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\..")
$py = ".\.venv\Scripts\python.exe"
switch ($What) {
    "api"      { & $py -m app serve }
    "bot"      { & $py -m app telegram-run }
    "selftest" { & $py -m app selftest }
}
