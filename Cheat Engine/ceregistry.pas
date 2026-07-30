unit ceregistry;

{
Wrapper to replace the creating and destroying of default level registry objects with a uniform method
}

{$mode delphi}

interface

uses
  {$ifdef darwin}
  macPort,
  {$endif}
  Classes, SysUtils, registry,
  {$if not defined(windows) and not defined(darwin) and not defined(jni)}linuxmemoryapi{$endif};

type
  TCEReg=class
  private
    reg: TRegistry;
    openedregistry: boolean;
    needsforce: boolean;
    triedforce: boolean;
    lastforce: qword;
    function getRegistry(force: boolean):boolean;
  public
    procedure writeBool(registryValueName: string; value: boolean);
    function readBool(registryValueName:string; def: boolean=false): boolean;
    procedure writeInteger(registryValueName: string; value: integer);
    function readInteger(registryValueName:string; def: integer=0): integer;
    procedure writeString(registryValueName: string; value: string);
    function readString(registryValueName:string; def: string=''): string;
    procedure writeStrings(registryValueName: string; sl: TStrings);
    procedure readStrings(registryValueName: string; sl: TStrings);

  end;

var cereg: TCEReg;

implementation

uses mainunit2;

function TCEReg.getRegistry(force: boolean):boolean;
begin
  {$ifdef darwin}
  //all registry objects access the same object. and that object has the current key set...
  if reg<>nil then
    reg.OpenKey('\Software\'+strCheatEngine+'\', false);


  {$endif}

  if not openedregistry then
  begin
    if triedforce and (gettickcount64<lastforce+2000) then exit(false);
    if needsforce and (force=false) then exit(false); //don't bother

    if reg=nil then
    begin
      {$if not defined(windows) and not defined(darwin)}
      //the registry is an XML file under the config directory here, and the
      //unit will not create that directory itself: without this every write
      //fails with ERegistryException before the main form is even up
      if not DirectoryExists(GetAppConfigDir(false)) then
        ForceDirectories(GetAppConfigDir(false));
      {$endif}
      reg:=tregistry.create;
    end;

    openedregistry:=reg.OpenKey('\Software\'+strCheatEngine+'\', force);

    if (not openedregistry) then
    begin
      if force then
      begin
        triedforce:=true;
        lastforce:=gettickcount64; //don't bother with trying for a few seconds (perhaps the user will fix it though ...)
      end
      else
        needsforce:=true;
    end;

    {$ifdef darwin}
    macPortFixRegPath;
    {$endif}
  end;


  result:=openedregistry;
end;

procedure TCEReg.writeStrings(registryValueName: string; sl: TStrings);
begin
  if getregistry(true) then
  begin
    try
      reg.WriteStringList(registryValueName, sl);
    except
    end;
  end;
end;

procedure TCEReg.readStrings(registryValueName: string; sl: TStrings);
begin
  sl.Clear;

  if getregistry(false) and (reg.ValueExists(registryValueName)) then
  begin
    try
      reg.ReadStringList(registryValueName, sl);
    except
    end;
  end;
end;

function TCEReg.readBool(registryValueName: string; def: boolean=false): boolean;
begin
  result:=def;
  if getregistry(false) and (reg.ValueExists(registryValueName)) then
  begin
    try
      result:=reg.ReadBool(registryValueName);
    except
    end;
  end;
end;

procedure TCEReg.writeBool(registryValueName: string; value: boolean);
begin
  if getregistry(true) then
  begin
    try
      reg.WriteBool(registryValueName, value);
    except
    end;
  end;
end;

function TCEReg.readInteger(registryValueName: string; def: integer=0): integer;
begin
  result:=def;
  if getregistry(false) and (reg.ValueExists(registryValueName)) then
  begin
    try
      result:=reg.ReadInteger(registryValueName);
    except
    end;
  end;
end;

procedure TCEReg.writeInteger(registryValueName: string; value: integer);
begin
  //writeBool and writeStrings already swallow this; these two did not, and on
  //Linux a failed settings write took the whole startup down with it
  if getregistry(true) then
  begin
    try
      reg.WriteInteger(registryValueName, value);
    except
      on e: Exception do
        writeln(stderr, 'registry: ', registryValueName, ': ', e.Message);
    end;
  end;
end;

function TCEReg.readString(registryValueName: string; def: string=''): string;
begin
  result:=def;
  if getregistry(false) and (reg.ValueExists(registryValueName)) then
  begin
    try
      result:=reg.ReadString(registryValueName);
    except
    end;
  end;
end;

procedure TCEReg.writeString(registryValueName: string; value: string);
begin
  if getregistry(true) then
  begin
    try
      reg.WriteString(registryValueName, value);
    except
      on e: Exception do
        writeln(stderr, 'registry: ', registryValueName, ': ', e.Message);
    end;
  end;
end;

initialization
  cereg:=TCEReg.Create;

end.

