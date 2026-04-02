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
// 自定义 Pascal Script 逻辑：优先非 C 盘的其它盘符进行安装（C 盘优先级最低）
function GetInstallDir(Param: String): String;
var
  DriveLetterCh: String;
  TestPath: String;
  AutoPfPath: String;
  TargetDrive: String;
  i: Integer;
begin
  AutoPfPath := ExpandConstant('{autopf}');
  TargetDrive := '';

  // 从 D 盘开始遍历到 Z 盘，寻找第一个有效且可写的本地磁盘
  for i := Ord('D') to Ord('Z') do
  begin
    DriveLetterCh := Chr(i);
    TestPath := DriveLetterCh + ':\';
    // 简单检查该根目录是否存在
    if DirExists(TestPath) then
    begin
      TargetDrive := DriveLetterCh + ':';
      break;
    end;
  end;

  // 如果 D-Z 都没有找到可用的盘符，那就只能妥协使用 C 盘（优先级最低）
  if TargetDrive = '' then
  begin
    TargetDrive := 'C:';
    // 如果系统默认路径（AutoPfPath）包含其他盘符前缀（例如 D:），将它强行改成 C:
    if (Length(AutoPfPath) >= 2) and (AutoPfPath[2] = ':') then
    begin
      Result := TargetDrive + Copy(AutoPfPath, 3, Length(AutoPfPath)) + '\{#MyAppName}';
    end
    else
    begin
      // 否则直接拼接（防止没有盘符的异常路径）
      Result := AutoPfPath + '\{#MyAppName}';
    end;
  end
  else
  begin
    // 找到了 D-Z 之间的盘符，替换原有路径中的盘符
    // 例如：C:\Program Files (x86) -> D:\Program Files (x86)
    if (Length(AutoPfPath) >= 2) and (AutoPfPath[2] = ':') then
    begin
      Result := TargetDrive + Copy(AutoPfPath, 3, Length(AutoPfPath)) + '\{#MyAppName}';
    end
    else
    begin
      // Fallback
      Result := TargetDrive + '\Program Files\{#MyAppName}';
    end;
  end;
end;