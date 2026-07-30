unit frmProcesswatcherExtraUnit;

{$MODE Delphi}

interface

uses
  LCLIntf, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, LResources, betterControls
  {$if not defined(windows) and not defined(darwin) and not defined(jni)}, linuxmemoryapi{$endif};

type
  TfrmProcessWatcherExtra = class(TForm)
    data: TMemo;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmProcessWatcherExtra: TfrmProcessWatcherExtra;

implementation


initialization
  {$i frmProcesswatcherExtraUnit.lrs}

end.
