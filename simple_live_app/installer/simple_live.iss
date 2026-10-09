; ============================================================================
;  Simple Live —— Windows 安装包脚本 (Inno Setup 6)
;
;  编译方式（三选一）：
;    1) 双击运行 installer\build_installer.bat
;    2) 命令行：ISCC.exe installer\simple_live.iss
;    3) Inno Setup Compiler GUI 打开本文件后按 F9
;
;  产物：installer\output\SimpleLive-Setup-<版本>.exe
;
;  前置条件：先执行 `flutter build windows --release` 生成 Release 目录，
;            并运行 deploy_vc_runtime.ps1 把 VC++ 运行时复制进 Release
;            （build_installer.bat 会自动做这两步）。
;  版本号自动从 build 出来的 simple_live_app.exe 读取（即 pubspec.yaml 的 version），
;  无需在本文件中手工同步。
; ============================================================================

#define AppName        "Simple Live"
#define AppPublisher   "com.xycz"
#define AppExeName     "simple_live_app.exe"
#define AppSourceDir   "..\build\windows\x64\runner\Release"
#define AppIconFile    "..\windows\runner\resources\app_icon.ico"

; ---- 从构建产物读取版本号，避免与 pubspec.yaml 不同步 ----
#define AppVersion     GetVersionNumbersString(AddBackslash(SourcePath) + AppSourceDir + "\" + AppExeName)

[Setup]
; 安装包 AppId：同一 AppId 的安装包会互相覆盖升级，切勿随意更改
AppId={{684394FE-D3A1-4D6F-BA2E-5BA896A40095}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
VersionInfoVersion={#AppVersion}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
VersionInfoDescription={#AppName} 安装程序
VersionInfoCompany={#AppPublisher}

; 安装到用户目录，无需管理员权限，避免弹 UAC
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
AllowNoIcons=yes

; 卸载时清理残留目录
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}

; 图标
SetupIconFile={#AppIconFile}
WizardStyle=modern

; 压缩：libmpv-2.dll 约 28MB，lzma2/ultra64 能把 84.7MB 压到 ~30MB 左右
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

OutputDir=output
OutputBaseFilename=SimpleLive-Setup-{#AppVersion}

; 64 位应用
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; 系统要求：Windows 10 1809+ （Flutter 桌面端与 WebView2 的最低要求）
MinVersion=10.0.17763

[Languages]
Name: "chinese"; MessagesFile: "ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; 整个 Release 目录（含 data\ 子目录、全部 dll 与 flutter_assets）
Source: "{#AppSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; 本程序以 GPL v3 分发，随包附上许可证副本（仓库根目录的 LICENSE）。
; skipifsourcedoesntexist：单独拷贝 simple_live_app 目录时不会因缺少该文件而编译失败。
Source: "..\..\LICENSE"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; 应用在 %APPDATA%\com.xycz\simple_live_app 下写配置与日志，属于用户数据，
; 卸载时默认保留（重装后可继续用）。如需彻底清除请手动删除该目录。
Type: filesandordirs; Name: "{app}\data"

[Code]
// ---------------------------------------------------------------------------
//  安装前：检测目标程序是否正在运行，避免覆盖正在使用的 dll 失败
// ---------------------------------------------------------------------------
function IsAppRunning(): Boolean;
var
  ResultCode: Integer;
  Cmd: String;
begin
  Cmd := '/C tasklist /FI "IMAGENAME eq {#AppExeName}" | find /I "{#AppExeName}" > nul';
  Result := Exec(ExpandConstant('{cmd}'), Cmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
            and (ResultCode = 0);
end;

function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  Result := True;
  if IsAppRunning() then
  begin
    if MsgBox('检测到 {#AppName} 正在运行，安装前需要先关闭它。' + #13#10 + #13#10 +
              '是否现在自动关闭并继续安装？', mbConfirmation, MB_YESNO) = IDYES then
    begin
      Exec(ExpandConstant('{cmd}'),
           '/C taskkill /F /IM {#AppExeName} > nul 2>&1',
           '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(800);
    end
    else
      Result := False;
  end;
end;
