unit modernfonts;

{
  Loads the bundled fonts so the interface does not depend on what Windows
  happens to have installed.

  Segoe UI and Consolas ship with Windows, but they are not ours to control:
  the version varies by release, and on Server installs the picture is worse.
  Inter and JetBrains Mono are both under the SIL Open Font License, so they
  can be shipped alongside and registered for this process only, with
  AddFontResourceEx and FR_PRIVATE. Nothing is installed system-wide and
  nothing is left behind when Cheat Engine closes.

  If a file is missing or fails to register, Loaded stays false and modernui
  falls back to the Windows fonts, so a trimmed-down copy still works.

  Pass NOBUNDLEDFONTS to ignore them and use the system fonts.
}

{$mode objfpc}{$H+}

interface

{$ifdef windows}
uses
  Classes, SysUtils, Windows;
{$else}
uses
  Classes, SysUtils;
{$endif}

var
  //true once the families below are available to this process
  UIFontLoaded: boolean = false;
  MonoFontLoaded: boolean = false;

const
  UIFontFamily = 'Inter';
  MonoFontFamily = 'JetBrains Mono';

implementation

{$ifdef windows}
const
  FR_PRIVATE = $10;

//neither is declared in FPC 3.2.2's Windows unit, so both are imported here
function AddFontResourceEx(lpFileName: PChar; fl: DWORD; pdv: Pointer): longint;
  stdcall; external 'gdi32.dll' name 'AddFontResourceExA';
function RemoveFontResourceEx(lpFileName: PChar; fl: DWORD; pdv: Pointer): BOOL;
  stdcall; external 'gdi32.dll' name 'RemoveFontResourceExA';

var
  loaded: TStringList = nil;

function FontDir: string;
var
  exeDir: string;
begin
  exeDir:=ExtractFilePath(ParamStr(0));

  //the executable sits in bin/ while fonts/ is next to it, one level up
  result:=exeDir+'fonts'+PathDelim;
  if DirectoryExists(result) then exit;

  result:=exeDir+'..'+PathDelim+'fonts'+PathDelim;
end;

function Register(const filename: string): boolean;
var
  fn: string;
begin
  result:=false;
  fn:=FontDir+filename;
  if not FileExists(fn) then exit;

  result:=AddFontResourceEx(PChar(fn), FR_PRIVATE, nil)>0;
  if result and (loaded<>nil) then
    loaded.Add(fn);
end;

procedure LoadBundledFonts;
var
  i: integer;
begin
  for i:=1 to ParamCount do
    if uppercase(ParamStr(i))='NOBUNDLEDFONTS' then exit;

  loaded:=TStringList.Create;

  //the regular weight decides whether the family is usable at all; the rest
  //only add weights the LCL can ask for
  UIFontLoaded:=Register('Inter-Regular.ttf');
  if UIFontLoaded then
  begin
    Register('Inter-Medium.ttf');
    Register('Inter-SemiBold.ttf');
    Register('Inter-Bold.ttf');
  end;

  MonoFontLoaded:=Register('JetBrainsMono-Regular.ttf');
  if MonoFontLoaded then
    Register('JetBrainsMono-Bold.ttf');
end;

procedure UnloadBundledFonts;
var
  i: integer;
begin
  if loaded=nil then exit;
  for i:=0 to loaded.Count-1 do
    RemoveFontResourceEx(PChar(loaded[i]), FR_PRIVATE, nil);
  FreeAndNil(loaded);
end;

initialization
  LoadBundledFonts;

finalization
  UnloadBundledFonts;

{$endif}

end.
