; Inno Setup 脚本 - KKMarkdown
; 生成传统的 Windows .exe 安装程序

#define MyAppName "KKMarkdown"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "fukaidong"
#define MyAppExeName "kkmarkdown.exe"
#define SourceFolder "..\build\windows\x64\runner\Release"
#define OutputFolder "..\outputs"

[Setup]
; 唯一标识符，请勿更改，以免影响旧版本覆盖升级
AppId={{060f4d59-a9a4-4561-9ae1-5822633d46ad}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
; 设置输出目录和安装包名称
OutputDir={#OutputFolder}
OutputBaseFilename={#MyAppName}_setup
; 采用最高压缩率
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; 卸载时是否删除整个目录
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 复制所有 Release 目录下的文件
Source: "{#SourceFolder}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceFolder}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; 注意: 不要在任何共享的系统文件上使用 "flags: ignoreversion"

[Icons]
; 开始菜单快捷方式
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
; 桌面快捷方式 (如果用户勾选)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; 安装完成后提供运行选项
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent