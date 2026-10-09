# ============================================================================
#  Simple Live —— 把 VC++ 运行时以「应用程序本地部署」方式放进 Release 目录
#
#  为什么需要：
#    simple_live_app.exe 及 16 个插件 dll 都依赖 MSVCP140.dll / VCRUNTIME140.dll /
#    VCRUNTIME140_1.dll（Flutter Windows 桌面端未静态链接 CRT）。
#    如果目标电脑没装「Microsoft Visual C++ 2015-2022 可再发行组件」，
#    程序会直接启动失败并提示找不到 VCRUNTIME140.dll。
#
#  为什么不用 vc_redist.x64.exe：
#    vc_redist 有 25MB，会把安装包从 26MB 撑到 ~50MB；而且需要管理员权限。
#    MSVC 2015 以后官方支持「本地部署」（app-local）：把这几个 dll 直接放到 exe
#    同目录即可，加载器优先使用应用程序目录，无需安装、无需管理员权限、体积仅 ~700KB。
#    UCRT（api-ms-win-crt-*.dll → ucrtbase.dll）自 Windows 10 起属于操作系统，无需附带。
#
#  用法：  powershell -ExecutionPolicy Bypass -File deploy_vc_runtime.ps1
# ============================================================================

[CmdletBinding()]
param(
    # 目标目录：留空则用脚本所在目录的 ..\build\windows\x64\runner\Release
    [string]$TargetDir = '',

    # 找不到时是否报错退出（CI 上可以设为 $false 只警告）
    [bool]$FailIfMissing = $true
)

$ErrorActionPreference = 'Stop'

# 注意：param 默认值里不能用 $PSScriptRoot（Windows PowerShell 5.1 求值时它还是空的）
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    $TargetDir = Join-Path $ScriptDir '..\build\windows\x64\runner\Release'
}

$TargetDir = [System.IO.Path]::GetFullPath($TargetDir)

# 只需要这三个：msvcp140.dll 自身只依赖 vcruntime140(_1) 与操作系统 UCRT
$Needed = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')

if (-not (Test-Path $TargetDir)) {
    Write-Host "[ERROR] Release 目录不存在：$TargetDir" -ForegroundColor Red
    Write-Host "        请先执行 flutter build windows --release"
    exit 1
}

# ---- 1. 定位 CRT 源目录 ------------------------------------------------------
# 候选来源：Visual Studio 的 Redist 目录（官方「可再发行」副本）与 System32
# （同样来自本机已安装的 VC++ 可再发行组件，属允许再分发的文件）。
# 两者都收进候选，最后按 msvcp140.dll 的文件版本取最新——新版本向后兼容旧工具集。
function Find-CrtDir {
    $roots = @(
        (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio'),
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio')
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    # 用显式通配符而不是 -Recurse：实际层级是
    #   <VS>\<年份>\<版本>\VC\Redist\MSVC\<工具集>\x64\Microsoft.VC*.CRT
    # 比 -Depth 能覆盖的更深，-Recurse -Depth 6 会漏掉。
    # 注意：路径含通配符时 Get-ChildItem 返回的是「被通配符匹配到的那一层」，
    # 所以模式必须一路写到 Microsoft.VC*.CRT 本身，不能再靠 -Filter 过滤子项。
    $candidates = @()
    foreach ($root in $roots) {
        $pattern = Join-Path $root '*\*\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT'
        $candidates += Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName
    }

    # System32 回退：要求三个文件齐全才作为候选
    $sys = Join-Path $env:WINDIR 'System32'
    $sysOk = $true
    foreach ($n in $Needed) {
        if (-not (Test-Path (Join-Path $sys $n))) { $sysOk = $false }
    }
    if ($sysOk) { $candidates += $sys }

    # 按 msvcp140.dll 的文件版本倒序，取最新
    $best = $candidates |
        Sort-Object -Property @{ Expression = {
                    try { (Get-Item (Join-Path $_ 'msvcp140.dll')).VersionInfo.FileVersionRaw }
                    catch { [version]'0.0.0' }
                } } -Descending |
        Select-Object -First 1

    return $best
}

$crtDir = Find-CrtDir

if (-not $crtDir) {
    $msg = "未找到可用的 VC++ 可再发行 CRT（既无 Visual Studio Redist 目录，System32 也不完整）。"
    if ($FailIfMissing) {
        Write-Host "[ERROR] $msg" -ForegroundColor Red
        Write-Host "        目标机器若未安装 VC++ 运行时，程序将无法启动。"
        exit 1
    } else {
        Write-Host "[WARN] $msg 已跳过本地部署。" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "[INFO] CRT 源目录：$crtDir"

# ---- 2. 复制到 Release 目录 --------------------------------------------------
$copied = 0
foreach ($name in $Needed) {
    $src = Join-Path $crtDir $name
    if (-not (Test-Path $src)) {
        Write-Host "[WARN] 缺少 $name，跳过" -ForegroundColor Yellow
        continue
    }
    Copy-Item $src -Destination (Join-Path $TargetDir $name) -Force
    $copied++
    Write-Host ("       + {0,-20} {1,9:N0} bytes" -f $name, (Get-Item $src).Length)
}

if ($copied -eq 0) {
    Write-Host "[ERROR] 一个文件都没复制成功" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] VC++ 运行时已本地部署到：$TargetDir" -ForegroundColor Green
exit 0
