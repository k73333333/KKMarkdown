<#
.SYNOPSIS
一键构建并打包 KKMarkdown Windows 客户端。

.DESCRIPTION
该脚本将执行以下操作：
1. 编译 Flutter Windows Release 版本。
2. 将构建好的 Release 文件夹压缩为“免安装绿色版”（kkmarkdown_portable.zip）。
3. 使用 msix 插件生成 Windows 安装包（.msix）。
4. 将生成的压缩包和安装包统一移动到项目根目录下的 release/ 成品目录中。
#>

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\kkk\Desktop\my\kkMarkdown"
$ReleaseDir = Join-Path $ProjectRoot "release"
$BuildReleaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$AppName = "kkmarkdown"

Write-Host "========== 开始构建 KKMarkdown ==========" -ForegroundColor Cyan

# 1. 确保成品目录存在并清理旧文件
if (!(Test-Path -Path $ReleaseDir)) {
    New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
} else {
    Write-Host "清理旧的成品目录..." -ForegroundColor Yellow
    Remove-Item -Path "$ReleaseDir\*" -Force -Recurse -ErrorAction SilentlyContinue
}

# 2. 执行 Flutter Build
Write-Host "`n[1/4] 正在编译 Flutter Windows Release..." -ForegroundColor Green
Set-Location $ProjectRoot
flutter build windows

# 3. 打包绿色版 (ZIP)
Write-Host "`n[2/4] 正在打包免安装绿色版 (ZIP)..." -ForegroundColor Green
$ZipPath = Join-Path $ReleaseDir "${AppName}_portable.zip"
if (Test-Path -Path $BuildReleaseDir) {
    Compress-Archive -Path "$BuildReleaseDir\*" -DestinationPath $ZipPath -Force
    Write-Host "绿色版打包完成: $ZipPath" -ForegroundColor DarkGreen
} else {
    Write-Host "错误: 找不到构建输出目录 $BuildReleaseDir" -ForegroundColor Red
    exit 1
}

# 4. 生成 MSIX 安装包
Write-Host "`n[3/4] 正在生成 MSIX 安装包..." -ForegroundColor Green
# 使用 dart run msix:create 生成安装包
# 忽略错误以便即使没证书报错也能复制出来
$ErrorActionPreference = "Continue"
dart run msix:create
$ErrorActionPreference = "Stop"

# 5. 移动 MSIX 到成品目录
Write-Host "`n[4/4] 正在收集成品..." -ForegroundColor Green
$MsixSource = Join-Path $BuildReleaseDir "${AppName}.msix"
$MsixDest = Join-Path $ReleaseDir "${AppName}_setup.msix"

if (Test-Path -Path $MsixSource) {
    Move-Item -Path $MsixSource -Destination $MsixDest -Force
    Write-Host "安装包已移动: $MsixDest" -ForegroundColor DarkGreen
} else {
    Write-Host "警告: 未能找到生成的 MSIX 文件 ($MsixSource)，可能生成失败。" -ForegroundColor Red
}

Write-Host "`n========== 构建与打包全部完成! ==========" -ForegroundColor Cyan
Write-Host "成品文件位于: $ReleaseDir" -ForegroundColor Cyan
Get-ChildItem -Path $ReleaseDir | Select-Object Name, Length | Format-Table
