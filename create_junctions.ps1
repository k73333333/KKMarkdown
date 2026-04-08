$json = Get-Content -Raw -Path .flutter-plugins-dependencies | ConvertFrom-Json
$windowsPlugins = $json.plugins.windows

$symlinksDir = "windows\flutter\ephemeral\.plugin_symlinks"
if (-not (Test-Path $symlinksDir)) {
    New-Item -ItemType Directory -Path $symlinksDir | Out-Null
}

foreach ($plugin in $windowsPlugins) {
    $name = $plugin.name
    $path = $plugin.path
    $linkPath = Join-Path $symlinksDir $name
    
    if (Test-Path $linkPath) {
        Remove-Item -Path $linkPath -Force -Recurse | Out-Null
    }
    
    Write-Host "Creating junction for $name -> $path"
    New-Item -ItemType Junction -Path $linkPath -Target $path | Out-Null
}
Write-Host "Done!"
