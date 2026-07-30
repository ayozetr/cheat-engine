unit ScrollBoxEx;

{$mode delphi}

interface

uses
  Classes, SysUtils, lmessages, forms, messages, betterControls
  {$if not defined(windows) and not defined(darwin) and not defined(jni)}, linuxmemoryapi{$endif};

type
  TScrollBox=class({$ifdef windows}betterControls.{$else}Forms.{$endif}TScrollbox)
  private
    procedure WMVScroll(var Msg: TLMessage); message WM_VSCROLL;
  public
    OnVScroll: TNotifyEvent;
end;

implementation

procedure TScrollBox.WMVScroll(var Msg: TLMessage);
begin
  if assigned(OnVScroll) then OnVScroll(self);

  inherited;
end;

end.

