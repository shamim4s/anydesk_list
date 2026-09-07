@echo off
setlocal EnableExtensions

title Roster → GitHub Gist

echo ================================================================
echo   Roster Gist Uploader
echo ================================================================
echo.

REM ================================================================
REM CONFIGURATION
REM ================================================================

set "DD_FILE=%APPDATA%\temp\dd.txt"

REM Your GitHub Gist ID
set "GIST_ID=YOUR_GIST_ID"

REM GitHub Personal Access Token
REM Better: set this as a Windows environment variable:
REM   setx GITHUB_TOKEN "github_pat_xxxxxxxxxxxxxxxxx"
if not defined GITHUB_TOKEN (
    echo [ERROR] GITHUB_TOKEN environment variable is not set.
    echo.
    echo Set it with:
    echo.
    echo   setx GITHUB_TOKEN "YOUR_GITHUB_TOKEN"
    echo.
    pause
    exit /b 1
)

set "GIST_FILE=roster.txt"

REM ================================================================
REM CHECK FILE
REM ================================================================

if not exist "%DD_FILE%" (
    echo [ERROR] File not found:
    echo %DD_FILE%
    echo.
    pause
    exit /b 1
)

echo [INFO] Source:
echo %DD_FILE%
echo.

REM ================================================================
REM CREATE TEMP POWERSHELL SCRIPT
REM ================================================================

set "PS1=%TEMP%\RosterUpload_%RANDOM%.ps1"

> "%PS1%" echo $ErrorActionPreference = 'Stop'
>>"%PS1%" echo.
>>"%PS1%" echo $ddFile = $env:DD_FILE
>>"%PS1%" echo $gistId = $env:GIST_ID
>>"%PS1%" echo $token = $env:GITHUB_TOKEN
>>"%PS1%" echo $gistFile = $env:GIST_FILE
>>"%PS1%" echo.
>>"%PS1%" echo Write-Host "[INFO] Reading dd.txt..."
>>"%PS1%" echo $text = [System.IO.File]::ReadAllText($ddFile)
>>"%PS1%" echo.
>>"%PS1%" echo # Find every ad.roster.items line
>>"%PS1%" echo $matches = [regex]::Matches($text, '(?m)^ad\.roster\.items=([^\r\n]*)')
>>"%PS1%" echo.
>>"%PS1%" echo if ($matches.Count -eq 0) {
>>"%PS1%" echo     Write-Host "[ERROR] No ad.roster.items entries found."
>>"%PS1%" echo     exit 1
>>"%PS1%" echo }
>>"%PS1%" echo.
>>"%PS1%" echo $localValues = @()
>>"%PS1%" echo.
>>"%PS1%" echo foreach ($m in $matches) {
>>"%PS1%" echo     $value = $m.Groups[1].Value.Trim()
>>"%PS1%" echo     if ($value) {
>>"%PS1%" echo         $localValues += $value
>>"%PS1%" echo     }
>>"%PS1%" echo }
>>"%PS1%" echo.
>>"%PS1%" echo Write-Host "[OK] Found $($localValues.Count) ad.roster.items entries."
>>"%PS1%" echo.
>>"%PS1%" echo # GitHub API
>>"%PS1%" echo $headers = @{
>>"%PS1%" echo     Authorization = "Bearer $token"
>>"%PS1%" echo     Accept = "application/vnd.github+json"
>>"%PS1%" echo     "X-GitHub-Api-Version" = "2022-11-28"
>>"%PS1%" echo }
>>"%PS1%" echo.
>>"%PS1%" echo $uri = "https://api.github.com/gists/$gistId"
>>"%PS1%" echo.
>>"%PS1%" echo Write-Host "[INFO] Reading existing Gist..."
>>"%PS1%" echo $gist = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
>>"%PS1%" echo.
>>"%PS1%" echo $existing = @()
>>"%PS1%" echo.
>>"%PS1%" echo if ($gist.files.$gistFile) {
>>"%PS1%" echo     $content = $gist.files.$gistFile.content
>>"%PS1%" echo     if ($content) {
>>"%PS1%" echo         $existing = $content -split "`r?`n" ^| Where-Object { $_.Trim() }
>>"%PS1%" echo     }
>>"%PS1%" echo }
>>"%PS1%" echo.
>>"%PS1%" echo # Merge and remove duplicates
>>"%PS1%" echo $all = @($existing) + @($localValues)
>>"%PS1%" echo $all = $all ^| ForEach-Object { $_.Trim() } ^| Where-Object { $_ } ^| Select-Object -Unique
>>"%PS1%" echo.
>>"%PS1%" echo $newContent = ($all -join "`r`n") + "`r`n"
>>"%PS1%" echo.
>>"%PS1%" echo $body = @{
>>"%PS1%" echo     files = @{
>>"%PS1%" echo         $gistFile = @{
>>"%PS1%" echo             content = $newContent
>>"%PS1%" echo         }
>>"%PS1%" echo     }
>>"%PS1%" echo } ^| ConvertTo-Json -Depth 5
>>"%PS1%" echo.
>>"%PS1%" echo Write-Host "[INFO] Updating Gist..."
>>"%PS1%" echo Invoke-RestMethod -Uri $uri -Headers $headers -Method Patch -Body $body -ContentType "application/json" ^| Out-Null
>>"%PS1%" echo.
>>"%PS1%" echo Write-Host "[OK] Gist updated successfully."
>>"%PS1%" echo Write-Host "[OK] Total stored entries: $($all.Count)"
>>"%PS1%" echo.

set "DD_FILE=%DD_FILE%"
set "GIST_ID=%GIST_ID%"
set "GIST_FILE=%GIST_FILE%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"

set "ERR=%ERRORLEVEL%"

del "%PS1%" >nul 2>&1

echo.
if "%ERR%"=="0" (
    echo ================================================================
    echo   UPLOAD COMPLETE
    echo ================================================================
) else (
    echo ================================================================
    echo   UPLOAD FAILED
    echo ================================================================
)

echo.
pause
exit /b %ERR%