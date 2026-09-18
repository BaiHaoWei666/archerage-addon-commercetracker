param([string]$PythonExecutable = 'python')
$ErrorActionPreference = 'Stop'
& $PythonExecutable (Join-Path $PSScriptRoot 'test.py')
if ($LASTEXITCODE -ne 0) { throw 'Lua 測試失敗' }
