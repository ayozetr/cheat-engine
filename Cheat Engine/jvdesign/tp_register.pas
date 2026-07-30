unit tp_register;

{$mode objfpc}

interface

uses
  Classes, SysUtils,
  {$if not defined(windows) and not defined(darwin) and not defined(jni)}linuxmemoryapi{$endif}; 

procedure register;


implementation
uses
  jvDesignSurface, LResources;

procedure Register;
begin
  RegisterComponents('Jv Runtime Design', [TJvDesignSurface, TJvDesignScrollBox, TJvDesignPanel]);
end;

initialization
  {$I test.lrs}

end.

