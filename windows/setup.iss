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
; 使用自定义的 GetInstallDir 函数动态计算非 D 盘路径
DefaultDirName={code:GetInstallDir}
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

[Code]
// 自定义 Pascal Script 逻辑
function GetInstallDir(Param: String): String;
var
  SystemDrive: String;
  AutoPfPath: String;
begin
  // 获取系统盘符 (通常为 C:)
  SystemDrive := ExpandConstant('{sysdrive}');
  // 获取默认的 Program Files 路径 (可能是 D:\Program Files，由用户系统配置决定)
  AutoPfPath := ExpandConstant('{autopf}');
  
  // 如果默认 Program Files 恰好是 D 盘，则强制改回系统盘(C盘)的 Program Files 
  if (Uppercase(Copy(AutoPfPath, 1, 2)) = 'D:') then
  begin
    // 替换盘符为系统盘，保留后缀路径
    Result := SystemDrive + Copy(AutoPfPath, 3, Length(AutoPfPath)) + '\{#MyAppName}';
  end
  else
  begin
    // 如果不是 D 盘，使用系统默认的 Program Files
    Result := AutoPfPath + '\{#MyAppName}';
  end;
end;