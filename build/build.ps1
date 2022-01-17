$ModuleName = 'Ut99Tools'
$SourceFolder = ($PSScriptRoot | Split-Path) + '/src'
$OutputPath = ($PSScriptRoot | Split-Path) + "/staging/$ModuleName"
Remove-Item -Path $OutputPath -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null 
Get-ChildItem -Path "$SourceFolder/*.ps1" -Recurse | Get-Content | Out-File -FilePath "$OutputPath\$ModuleName.psm1"
Copy-Item "$SourceFolder/*" -Recurse -Exclude '*.ps1' -Destination $OutputPath
$OutputPath | Write-Output 