; Inno Setup script — packages the `flutter build windows --release` output
; into a single self-contained installer (TemidoveCRM-Setup.exe), replacing
; the old "hand the client a folder full of .exe/.dll files and a zip"
; distribution with a normal Windows install/uninstall experience.
;
; Built by CI (.github/workflows/build-windows.yml) via ISCC.exe, which
; ships preinstalled on GitHub's windows-latest runners. To build locally,
; install Inno Setup (https://jrsoftware.org/isinfo.php) and run:
;   flutter build windows --release
;   iscc windows\installer\temidove_crm.iss
;
; MyAppVersion is passed in from CI via `/DMyAppVersion=x.y.z` (extracted
; from pubspec.yaml so the two never drift apart); it defaults to 0.0.0
; for a local build where that define isn't supplied.
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#define MyAppName "Temidove CRM"
#define MyAppPublisher "Temidove Smart Solutions"
#define MyAppExeName "temidove_crm.exe"
; Fixed at creation time — never change this for an existing install line,
; it's how Windows/Inno recognize "this is an upgrade" vs "a new app".
#define MyAppId "{{5F1B9C1E-6C0F-4B62-9C36-3B6E2C6E6C31}"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Installs to Program Files, which needs elevation - appropriate for a
; shared office PC where any staff account should be able to launch it.
PrivilegesRequired=admin
OutputDir=..\..\installer_output
OutputBaseFilename=TemidoveCRM-Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Plain "x64" rather than the newer "x64compatible" keyword (Inno Setup
; 6.3+) — safer against whatever Inno Setup version happens to be
; preinstalled on the CI runner (see the workflow's ISCC step).
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Everything flutter build windows produces — exe, flutter_windows.dll,
; plugin DLLs, and the data\ folder (assets + AOT snapshot). Recursive
; because data\ has its own subfolders (flutter_assets\, icudtl.dat, etc).
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; The local SQLite database lives under the per-user AppData folder (see
; getApplicationSupportDirectory() in lib/database/database.dart), not
; under {app} — deliberately NOT removed on uninstall, so re-installing
; the app (e.g. to upgrade) doesn't silently wipe live student/payment
; data. Staff data removal, if ever wanted, should be a manual/explicit
; step, never an uninstaller side effect.
