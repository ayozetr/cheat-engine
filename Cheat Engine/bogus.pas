unit bogus; 

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs
  {$if not defined(windows) and not defined(darwin) and not defined(jni)}, linuxmemoryapi{$endif}; 

type
  TForm1 = class(TForm)
  private
    { private declarations }
  public
    { public declarations }
  end; 

var
  Form1: TForm1; 

implementation

initialization
  {$I bogus.lrs}

end.

