unit newForm;

{$mode objfpc}{$H+}

interface

uses
  jwawindows, windows, Classes, SysUtils, forms, controls, messages, lmessages,
  Win32Extra, LCLClasses,LCLProc;

type
  TNewForm=class(TForm)
  private
  protected
   // procedure WndProc(var TheMessage: TLMessage); override;
  public
    constructor Create(TheOwner: TComponent); override;
    constructor CreateNew(AOwner: TComponent; Num: Integer=0); override;
  published
  end;


implementation

uses graphics, Menus, Win32WSMenus, betterControls, DwmApi, modernui, modernicons, modernabout;

constructor TNewForm.Create(TheOwner: TComponent);
var ldark: dword;
begin
  inherited create(TheOwner);

  //betterControls declares globalCustomDraw but never assigns it, and
  //fCustomDraw defaults to false, so csCustomPaint is never set and
  //DefaultCustomPaint never runs: Windows paints the controls itself.
  //Turning it on is what lets us control how they look.
  globalCustomDraw:=ModernMetrics.CustomDraw;

  //the .lfm has been streamed in by now, so the child controls exist
  ApplyModernUI(self);
  ApplyModernIcons(self);
  ApplyModernAbout(self);

  if ShouldAppsUseDarkMode() then
  begin
    AllowDarkModeForWindow(handle,1);


    color:=$242424;
    //most .lfm files name a colour here, usually clWindowText, so testing for
    //clDefault first left the form black on black
    if ModernMetrics.CustomDraw or (font.color=clDefault) then
      font.color:=colorset.FontColor;


    if InitDwmLibrary then
    begin
      ldark:=1;
      DwmSetWindowAttribute(handle, 19, @Ldark, sizeof(Ldark));
    end;
  end;
end;

constructor TNewForm.CreateNew(AOwner: TComponent; Num: Integer=0);
var ldark: dword;
begin
  inherited CreateNew(AOwner, num);
  if ShouldAppsUseDarkMode() then
  begin
    AllowDarkModeForWindow(handle,1);

    color:=$242424;
    font.color:=colorset.FontColor;
    if InitDwmLibrary then
    begin
      ldark:=1;

      DwmSetWindowAttribute(handle, 20, @Ldark, sizeof(Ldark));
    end;
  end;
end;

end.

