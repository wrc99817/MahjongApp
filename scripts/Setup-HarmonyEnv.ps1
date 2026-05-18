param(
  [string]$SdkRoot = "",
  [switch]$Persist
)

$ErrorActionPreference = "Stop"

function Add-UniquePath([string[]]$Paths) {
  $current = [Environment]::GetEnvironmentVariable("Path", "User")
  $parts = @()
  if ($current) {
    $parts = $current -split ";"
  }

  foreach ($path in $Paths) {
    if ([string]::IsNullOrWhiteSpace($path)) {
      continue
    }
    if (-not (Test-Path $path)) {
      continue
    }
    if ($parts -notcontains $path) {
      $parts += $path
      Write-Host "PATH + $path" -ForegroundColor Green
    }
  }

  if ($Persist) {
    [Environment]::SetEnvironmentVariable("Path", ($parts -join ";"), "User")
  }
}

function Find-FirstExisting([string[]]$Candidates) {
  foreach ($candidate in $Candidates) {
    if (Test-Path $candidate) {
      return (Resolve-Path $candidate).Path
    }
  }
  return ""
}

function Find-ToolDirs([string]$Root, [string[]]$Patterns) {
  $dirs = New-Object System.Collections.Generic.List[string]
  foreach ($pattern in $Patterns) {
    Get-ChildItem -Path $Root -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue |
      ForEach-Object {
        if (-not $dirs.Contains($_.DirectoryName)) {
          $dirs.Add($_.DirectoryName)
        }
      }
  }
  return $dirs.ToArray()
}

if ([string]::IsNullOrWhiteSpace($SdkRoot)) {
  $SdkRoot = Find-FirstExisting @(
    "$env:LOCALAPPDATA\Huawei\Sdk",
    "$env:LOCALAPPDATA\OpenHarmony\Sdk",
    "$env:USERPROFILE\AppData\Local\Huawei\Sdk",
    "D:\Huawei\Sdk",
    "D:\HarmonyOS\Sdk"
  )
}

if ([string]::IsNullOrWhiteSpace($SdkRoot)) {
  Write-Host "No HarmonyOS/OpenHarmony SDK directory found." -ForegroundColor Yellow
  Write-Host "Install DevEco Studio, then install HarmonyOS SDK and Emulator from SDK Manager, then rerun this script." -ForegroundColor Yellow
  exit 2
}

$SdkRoot = (Resolve-Path $SdkRoot).Path
Write-Host "SDK root: $SdkRoot" -ForegroundColor Cyan

if ($Persist) {
  [Environment]::SetEnvironmentVariable("HARMONY_SDK_HOME", $SdkRoot, "User")
  [Environment]::SetEnvironmentVariable("OHOS_SDK_HOME", $SdkRoot, "User")
  [Environment]::SetEnvironmentVariable("DEVECO_SDK_HOME", $SdkRoot, "User")
  Write-Host "Persisted HARMONY_SDK_HOME/OHOS_SDK_HOME/DEVECO_SDK_HOME" -ForegroundColor Green
}

$toolDirs = Find-ToolDirs $SdkRoot @("hdc*.exe", "hvigor*.cmd", "hvigor*.bat", "ohpm*.cmd", "ohpm*.bat")
Add-UniquePath $toolDirs

Write-Host ""
Write-Host "Detected tool directories:" -ForegroundColor Cyan
$toolDirs | ForEach-Object { Write-Host $_ }

Write-Host ""
Write-Host "Done. Open a new terminal for persisted PATH changes to take effect." -ForegroundColor Cyan
