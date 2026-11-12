# First-time setup on Windows. Run in PowerShell from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\windows\setup.ps1
# Needs Python 3.11+  (install: winget install Python.Python.3.12)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\..")
if (-not (Get-Command py -ErrorAction SilentlyContinue) -and -not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Error "Python not found. Run: winget install Python.Python.3.12  (then reopen PowerShell)"
}
$py = if (Get-Command py -ErrorAction SilentlyContinue) { "py" } else { "python" }
if (-not (Test-Path ".venv")) { & $py -m venv .venv }
& .\.venv\Scripts\python.exe -m pip install --upgrade pip
& .\.venv\Scripts\python.exe -m pip install -r requirements.txt
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example - open it in Notepad and fill in your values." -ForegroundColor Yellow
}
& .\.venv\Scripts\python.exe -m app init-db
& .\.venv\Scripts\python.exe -m app selftest
& .\.venv\Scripts\python.exe -m pytest
Write-Host "Setup finished." -ForegroundColor Green
