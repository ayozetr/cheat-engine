unit CodeFilterCallOrAllDialog;

{$mode delphi}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, betterControls,
  {$if not defined(windows) and not defined(darwin) and not defined(jni)}linuxmemoryapi{$endif};

type

  { TCallOrAllDialog }

  TCallOrAllDialog = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Label1: TLabel;
    Panel1: TPanel;
  private
    { private declarations }
  public
    { public declarations }
  end;

implementation

{$R *.lfm}

end.

