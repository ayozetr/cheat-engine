unit NullStream;

{$mode delphi}

interface

uses
  Classes, SysUtils
  {$if not defined(windows) and not defined(darwin) and not defined(jni)}, linuxmemoryapi{$endif};

type TNullStream=class(TStream)
  private
  public
    function Write(const Buffer; Count: Longint): Longint; override;
end;


implementation

function TNullStream.Write(const Buffer; Count: Longint): Longint;
begin
  result:=count;
end;


end.

