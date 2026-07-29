; SolidExpress — Inno Setup 6. CI: iscc /DMyAppVersion=X.Y.Z
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef MySourceDir
  #define MySourceDir "..\..\dist\releases\SolidExpress-{#MyAppVersion}-windows-x86_64"
#endif
[Setup]
AppId={{A7B3C4D5-E6F7-4890-ABCD-SOLIDEXPRESS01}
AppName=SolidExpress
AppVersion={#MyAppVersion}
AppPublisher=Express Consortium
AppPublisherURL=https://github.com/solidexpress/solidexpress
DefaultDirName={autopf}\SolidExpress
OutputDir=..\..\dist\releases
OutputBaseFilename=SolidExpress-{#MyAppVersion}-x64-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
PrivilegesRequired=lowest
[Files]
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
[Icons]
Name: "{group}\SolidExpress"; Filename: "{app}\SolidExpress.exe"
[Run]
Filename: "{app}\SolidExpress.exe"; Flags: nowait postinstall skipifsilent
