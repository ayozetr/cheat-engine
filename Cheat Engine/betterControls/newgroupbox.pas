unit newGroupBox; //for some reason parentfont does not work

{$mode objfpc}{$H+}

interface

uses
  jwawindows, windows, Classes, SysUtils, Controls, StdCtrls, LCLType,
  lmessages,graphics, ExtCtrls;

type
  TNewGroupBox=class(TGroupBox)
  private
  protected
    //procedure PaintControls(DC: HDC; First: TControl);
    procedure ChildHandlesCreated; override;
  public


  end;



function GroupBoxSubClass(wnd:HWND; msg:UINT; _wparam:WPARAM; _lparam:LPARAM):LRESULT; stdcall;
 
var
  OriginalGroupBoxHandler: ptruint;

//function GroupBoxSubClass(wnd:HWND; msg:UINT; _wparam:WPARAM; _lparam:LPARAM):LRESULT; stdcall;

implementation

uses betterControls, modernui, WSLCLClasses, WSStdCtrls, Win32Proc, Win32Int;

type
  TCustomGroupBoxHelper = class helper for TCustomGroupBox
  public
    procedure PaintControlsHelper(DC: HDC; First: TControl);
    function GetParentColor: boolean;
  end;

procedure TCustomGroupBoxHelper.PaintControlsHelper(DC: HDC; First: TControl);
begin
  PaintControls(dc,first);
end;

function TCustomGroupBoxHelper.GetParentColor: boolean;
begin
  result:=ParentColor;
end;


function GroupBoxSubClass(wnd:HWND; msg:UINT; _wparam:WPARAM; _lparam:LPARAM):LRESULT; stdcall;
var
  Info: PWin32WindowInfo;
  ps: windows.TPaintStruct;
  dc: hdc;

  c: TCanvas;

  gb: TCustomGroupBox;
  r:trect;
  h: LPNMHDR;
  i: integer;
  p: tpoint;
begin

  if msg=WM_PAINT then
  begin
    Info := GetWin32WindowInfo(wnd);
    if (info<>nil) and (info^.WinControl is TCustomGroupBox) then
    begin
      gb:=TCustomGroupBox(info^.WinControl);

      dc:=BeginPaint(wnd, ps);
      if dc<>0 then
      begin
        c:=tcanvas.create;
        c.handle:=dc;
        c.brush.style:=bsSolid;

        if (gb.color=clDefault) and gb.getParentColor then
          c.brush.color:=gb.GetRGBColorResolvingParent
        else
          c.brush.color:=gb.color;

        //clWindowFrame is a hard white line: the classic 2005 group box.
        //A muted border reads as a grouping instead of a boxed-in frame.
        if ModernMetrics.CustomDraw then
          c.Pen.color:=ModernMetrics.GroupBoxBorder
        else
          c.Pen.color:=clWindowFrame;
        c.FillRect(ps.rcPaint);


        r:=rect(0,c.TextHeight('Q') div 2,gb.width,gb.height);
        c.brush.Style:=bsClear;
        if ModernMetrics.CornerRadius>0 then
          c.RoundRect(r.Left, r.Top, r.Right, r.Bottom,
                      ModernMetrics.CornerRadius*2, ModernMetrics.CornerRadius*2)
        else
          c.Rectangle(r);

        c.font.color:=gb.font.color;
        c.brush.Style:=bsSolid;

        c.TextOut(10,0,gb.Caption);
        c.free;


        if gb.ControlCount>0 then
        begin
          p:=gb.ScreenToControl(gb.ClientToScreen(point(0,0)));
          MoveWindowOrg(dc,p.x, p.y);
          gb.PaintControlsHelper(dc,gb.controls[0]);
        end;

        EndPaint(wnd,ps);
        exit(0);
      end;


    end;

  end;



  result:=CallWindowProc(windows.WNDPROC(OriginalGroupBoxHandler), wnd, msg, _wparam, _lparam);
end;

  {
procedure TNewGroupBox.PaintControls(DC: HDC; First: TControl);
begin
  inherited PaintControls(DC, First);
end;}

procedure TNewGroupBox.ChildHandlesCreated;
begin
  inherited ChildHandlesCreated;
  if ShouldAppsUseDarkMode then
  begin
    if OriginalGroupBoxHandler=0 then
      OriginalGroupBoxHandler:=SetWindowLongPtr(handle, GWLP_WNDPROC, UINT_PTR(@GroupBoxSubClass))
    else
      SetWindowLongPtr(handle, GWLP_WNDPROC, UINT_PTR(@GroupBoxSubClass));
  end;

end;


end.

