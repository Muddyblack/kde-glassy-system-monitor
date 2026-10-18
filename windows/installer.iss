; Windows installer for Glassy System Monitor (Inno Setup 6.3 or later).
;
; Built by windows/build-installer.ps1 from PyInstaller's "dist\Glassy System
; Monitor" folder (windows/glassy-system-monitor.spec), in
; .github/workflows/windows.yml.
;
; Per user: no admin rights, installed to %LOCALAPPDATA%\Programs\Glassy System
; Monitor. The monitor itself runs as a normal user; only its opt-in hardware
; sensors (tray menu) ask for administrator rights, when switched on.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
; Never change the AppId: it is how Windows knows a new version is the same
; app and updates it in place.
AppId={{2971B94C-CD18-40F0-B88C-E42EBB158B3A}
AppName=Glassy System Monitor
AppVersion={#AppVersion}
AppVerName=Glassy System Monitor {#AppVersion}
AppPublisher=Muddyblack
AppPublisherURL=https://github.com/Muddyblack/kde-glassy-system-monitor
AppSupportURL=https://github.com/Muddyblack/kde-glassy-system-monitor/issues
DefaultDirName={autopf}\Glassy System Monitor
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..
OutputBaseFilename=Glassy-System-Monitor-Setup-{#AppVersion}
SetupIconFile=..\dist\glassy-system-monitor.ico
UninstallDisplayIcon={app}\Glassy System Monitor.exe
UninstallDisplayName=Glassy System Monitor
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; The running app is stopped in [Code] instead of by the Restart Manager,
; which would ask the user about a tray app with no window to close.
CloseApplications=no

[Tasks]
; Offered on a first install only. On an update it would apply the choice
; remembered from that install, turning autostart back on for someone who had
; switched it off since; left out, the Run value stays as it is.
Name: "autostart"; Description: "Start Glassy System Monitor when I sign in"; Check: not IsUpgrade
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\dist\Glassy System Monitor\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; An update replaces the whole bundle: files a new PyInstaller build no
; longer has must not linger next to the ones it does.
Type: filesandordirs; Name: "{app}\_internal"

[Icons]
Name: "{autoprograms}\Glassy System Monitor"; Filename: "{app}\Glassy System Monitor.exe"
Name: "{autodesktop}\Glassy System Monitor"; Filename: "{app}\Glassy System Monitor.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Glassy System Monitor"; ValueData: """{app}\Glassy System Monitor.exe"""; Tasks: autostart
; Removed on uninstall whichever way it was turned on.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "Glassy System Monitor"; Flags: uninsdeletevalue

[Run]
Filename: "{app}\Glassy System Monitor.exe"; Description: "{cm:LaunchProgram,Glassy System Monitor}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM ""Glassy System Monitor.exe"""; Flags: runhidden; RunOnceId: "StopGlassySystemMonitor"

[Code]
var
  WasRunning: Boolean;

// An earlier install is there: its uninstaller is registered under AppId
// (with the doubled brace undone) plus "_is1". Keep the GUID in step with
// AppId above.
function IsUpgrade: Boolean;
var
  Uninstaller: String;
begin
  Result := RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{2971B94C-CD18-40F0-B88C-E42EBB158B3A}_is1', 'UninstallString', Uninstaller);
end;

// Stop a running copy before its files are replaced. taskkill exits 0 when it
// stopped something and 128 when nothing was running. An elevated copy (the
// sensors option) cannot be stopped from here and is reported as still running
// by the file replacement, which Inno Setup then offers to retry.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  WasRunning := Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM "Glassy System Monitor.exe"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
  Result := '';
end;

// A silent update (/SILENT, winget) skips the [Run] entry's checkbox, which
// would leave the app stopped until the next sign-in: start it again when it
// was running before.
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if (CurStep = ssPostInstall) and WizardSilent and WasRunning then
    ExecAsOriginalUser(ExpandConstant('{app}\Glassy System Monitor.exe'), '', '', SW_SHOWNORMAL, ewNoWait, ResultCode);
end;
