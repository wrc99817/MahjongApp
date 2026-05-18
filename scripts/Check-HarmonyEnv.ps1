param()

$ErrorActionPreference = "SilentlyContinue"

function Find-CommandPath([string]$Name) {
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }
  return ""
}

$items = @(
  [PSCustomObject]@{ Name = "node"; Path = Find-CommandPath "node" },
  [PSCustomObject]@{ Name = "npm"; Path = Find-CommandPath "npm" },
  [PSCustomObject]@{ Name = "java"; Path = Find-CommandPath "java" },
  [PSCustomObject]@{ Name = "hdc"; Path = Find-CommandPath "hdc" },
  [PSCustomObject]@{ Name = "hvigor"; Path = Find-CommandPath "hvigor" },
  [PSCustomObject]@{ Name = "ohpm"; Path = Find-CommandPath "ohpm" }
)

Write-Host "Command availability:" -ForegroundColor Cyan
$items | Format-Table -AutoSize

Write-Host ""
Write-Host "User environment:" -ForegroundColor Cyan
@("HARMONY_SDK_HOME", "OHOS_SDK_HOME", "DEVECO_SDK_HOME", "JAVA_HOME") | ForEach-Object {
  [PSCustomObject]@{
    Name = $_
    Value = [Environment]::GetEnvironmentVariable($_, "User")
  }
} | Format-Table -AutoSize

Write-Host ""
Write-Host "Likely SDK directories:" -ForegroundColor Cyan
@(
  "$env:LOCALAPPDATA\Huawei\Sdk",
  "$env:LOCALAPPDATA\OpenHarmony\Sdk",
  "$env:USERPROFILE\AppData\Local\Huawei\Sdk",
  "D:\Huawei\Sdk",
  "D:\HarmonyOS\Sdk"
) | Where-Object { Test-Path $_ } | ForEach-Object { Write-Host $_ }
