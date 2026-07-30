unit modernui;

{
  Applies modern UI metrics to forms at runtime.

  Cheat Engine's .lfm files were designed with Windows XP era metrics: most
  controls are 15 to 19 pixels high with an 8pt font. That is what makes the
  interface look dated, far more than the color scheme does.

  Rewriting 164 .lfm files by hand is not realistic (MemoryBrowserFormUnit.lfm
  alone is 21k lines), but 123 of them use AnchorSide based layout, so growing
  a control makes its neighbours reflow on their own. This unit walks the
  control tree once per form and bumps the metrics.

  A bigger font makes captions wider, so the form itself has to grow with it,
  otherwise controls anchored to the right edge get clipped. AutoAdjustLayout
  is the LCL's own DPI scaling path, so it moves the form and its children
  together; we drive it with the ratio between the old and new text height.

  Hooked from TNewForm.Create, so it reaches every form that uses betterControls.
  Pass MODERNUI=0 on the command line to disable it and compare.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Forms, Graphics, StdCtrls, ExtCtrls, Buttons,
  ComCtrls, LCLIntf, LCLType;

type
  TModernUIMetrics = record
    Enabled: boolean;
    //betterControls sets this once it knows; asking it directly would be a
    //circular reference, since it already uses this unit
    DarkMode: boolean;
    FontName: string;
    FontSize: integer;
    EditHeight: integer;      //edits, combos, spin edits
    ButtonHeight: integer;
    ToggleHeight: integer;    //checkboxes and radio buttons
    Spacing: integer;         //BorderSpacing.Around
    CornerRadius: integer;    //read by newbutton/newedit when painting
    ScaleForms: boolean;
    WidthSlack: single;       //extra room for AutoSize captions
    CustomDraw: boolean;      //drives betterControls' globalCustomDraw

    //Palette for the dark theme. betterControls' own defaults (clDkGray,
    //clActiveBorder, clBtnHiLight) were written for a light theme and never
    //ran, so they were never tuned: on the dark form background they come out
    //as pale grey buttons with a white border. TColor is $00BBGGRR, but these
    //are neutral greys so the byte order does not matter.
    ButtonFace: TColor;
    ButtonFaceHover: TColor;
    ButtonFaceDown: TColor;
    ButtonFaceDisabled: TColor;
    ButtonBorder: TColor;
    ButtonBorderHover: TColor;
    Text: TColor;
    TextDisabled: TColor;
    GroupBoxBorder: TColor;
    CheckboxFill: TColor;
    CheckboxMark: TColor;
    CheckboxFillDisabled: TColor;

    //Everything so far is grey. An accent on what is active or selected is
    //what separates a dark theme from a flat one. Taken from the Cheat Engine
    //logo so it reads as the same product. TColor is $00BBGGRR, hence the
    //byte order looking reversed.
    Accent: TColor;
    AccentText: TColor;
    MenuBackground: TColor;     //fondo de los desplegables
    MenuBarBackground: TColor;  //barra de menu de la ventana
    MenuSeparator: TColor;

    //Courier New is hardcoded in 53 places across the .lfm and .pas files and
    //is most of why the result list and the memory viewer look dated. Any
    //control still carrying it gets switched to this one.
    MonoFontName: string;
    ModernIcons: boolean;     //read by modernicons
    ModernAbout: boolean;     //read by modernabout
  end;

var
  //not named ModernUI: that identifier is taken by the unit itself
  ModernMetrics: TModernUIMetrics;

procedure ApplyModernUI(form: TCustomForm);

implementation

uses modernfonts;

type
  //CE restores fonts from the registry after the form is built
  //(LoadFontFromRegistry in MainUnit), which overwrites the mono font swap
  //done in the constructor. Reapplying on show puts it back.
  TShowHook = class
    original: TNotifyEvent;
    procedure Show(Sender: TObject);
  end;

procedure SwapMonoFonts(parent: TWinControl); forward;
function EsOscuro(c: TColor): boolean;
var
  r,g,b: byte;
begin
  RedGreenBlue(c, r, g, b);
  //rough perceived brightness; the form sits at $242424
  result:=(r*30 + g*59 + b*11) div 100 < 110;
end;

procedure SwapTextColors(parent: TWinControl); forward;
procedure StyleListHeaders(parent: TWinControl; f: TFont); forward;

procedure TShowHook.Show(Sender: TObject);
begin
  if original<>nil then original(Sender);
  if Sender is TWinControl then
  begin
    SwapMonoFonts(TWinControl(Sender));
    //controls created after the form was built get their turn here
    if ModernMetrics.CustomDraw and ModernMetrics.DarkMode then
      SwapTextColors(TWinControl(Sender));
    if Sender is TCustomForm then
      StyleListHeaders(TWinControl(Sender), TCustomForm(Sender).Font);
  end;
end;

procedure StyleListHeaders(parent: TWinControl; f: TFont);
//The column values are monospaced so hex addresses line up, but the header
//gains nothing from it and loses width: "Anterior" was being cut to "An...".
//A list view's header is a separate window, so it can take its own font.
const
  LVM_GETHEADER = $1000 + 31;
  WM_SETFONT_ = $0030;      //LCLType does not export it under this name
var
  i: integer;
  c: TControl;
  hdr: HWND;
begin
  for i:=0 to parent.ControlCount-1 do
  begin
    c:=parent.Controls[i];

    if (c is TCustomListView) and TWinControl(c).HandleAllocated then
    begin
      hdr:=HWND(SendMessage(TWinControl(c).Handle, LVM_GETHEADER, 0, 0));
      if hdr<>0 then
        SendMessage(hdr, WM_SETFONT_, WPARAM(f.Reference.Handle), 1);
    end;

    if c is TWinControl then
      StyleListHeaders(TWinControl(c), f);
  end;
end;

function IsLegacyMono(const name: string): boolean;
begin
  //Courier New comes from the .lfm files and Consolas from the ones already
  //switched over; both give way to the bundled family when it is available
  result:=SameText(name, 'Courier New') or SameText(name, 'Consolas');
end;

procedure SwapMonoFonts(parent: TWinControl);
var
  i: integer;
  c: TControl;
begin
  for i:=0 to parent.ControlCount-1 do
  begin
    c:=parent.Controls[i];
    if IsLegacyMono(c.Font.Name) and
       (not SameText(c.Font.Name, ModernMetrics.MonoFontName)) then
      c.Font.Name:=ModernMetrics.MonoFontName;
    if c is TWinControl then
      SwapMonoFonts(TWinControl(c));
  end;
end;


{
  The dark palette only covers backgrounds. Every control that names a colour
  in its .lfm — and most name clWindowText — keeps painting its caption black,
  which on a dark form is invisible. Walk the tree and give them the palette's
  foreground, leaving alone anything deliberately coloured.
}
procedure SwapTextColors(parent: TWinControl);
var
  i: integer;
  c: TControl;
begin
  for i:=0 to parent.ControlCount-1 do
  begin
    c:=parent.Controls[i];

    //comparing against clWindowText is no good: betterControls reassigns it,
    //so the control still holds the old value. Judge by brightness instead —
    //anything too dark to read on this background gets the palette colour,
    //and deliberate bright or coloured captions are left alone.
    if (c.Font.Color=clDefault) or EsOscuro(ColorToRGB(c.Font.Color)) then
      c.Font.Color:=ModernMetrics.Text;

    if c is TWinControl then
      SwapTextColors(TWinControl(c));
  end;
end;

function TextHeightFor(f: TFont): integer;
var
  bmp: TBitmap;
begin
  //the form's own canvas isn't reliable this early, so measure off-screen
  result:=0;
  bmp:=TBitmap.Create;
  try
    bmp.SetSize(1,1);
    bmp.Canvas.Font.Assign(f);
    result:=bmp.Canvas.TextHeight('Wg');
  finally
    bmp.Free;
  end;
end;

procedure BumpHeight(c: TControl; target: integer);
begin
  //only ever grow, and never fight a control that sizes itself
  if c.AutoSize then exit;
  if c.Height >= target then exit;

  c.Height:=target;
end;

procedure ApplySpacing(c: TControl);
begin
  //don't add spacing to controls that are meant to fill their parent
  if c.Align in [alClient, alTop, alBottom, alLeft, alRight] then exit;
  if c.BorderSpacing.Around > 0 then exit;

  c.BorderSpacing.Around:=ModernMetrics.Spacing;
end;

procedure WalkControls(parent: TWinControl);
var
  i: integer;
  c: TControl;
begin
  for i:=0 to parent.ControlCount-1 do
  begin
    c:=parent.Controls[i];

    //applies to every control, including the ones skipped below: the result
    //list and the memory viewer are exactly the ones carrying a fixed font
    if IsLegacyMono(c.Font.Name) and
       (not SameText(c.Font.Name, ModernMetrics.MonoFontName)) then
      c.Font.Name:=ModernMetrics.MonoFontName;

    if (c is TCustomEdit) or (c is TCustomComboBox) then
    begin
      BumpHeight(c, ModernMetrics.EditHeight);
      ApplySpacing(c);
    end
    else if (c is TCustomButton) or (c is TCustomSpeedButton) then
    begin
      BumpHeight(c, ModernMetrics.ButtonHeight);
      ApplySpacing(c);
    end
    else if (c is TCustomCheckBox) or (c is TRadioButton) then
    begin
      BumpHeight(c, ModernMetrics.ToggleHeight);
      ApplySpacing(c);
    end
    else if c is TLabel then
    begin
      //a label anchored below another control sits flush against it, which
      //with the larger font reads as cramped: "Encontrados:" ended up touching
      //the progress bar above it
      if (c.AnchorSide[akTop].Control<>nil) and
         (c.AnchorSide[akTop].Side=asrBottom) and
         (c.BorderSpacing.Top=0) then
        c.BorderSpacing.Top:=ModernMetrics.Spacing*2;
    end;

    //recurse into panels, groupboxes, tabsheets, scrollboxes...
    //listviews and treeviews own their internals, leave them alone
    if (c is TWinControl) and
       (not (c is TCustomListView)) and
       (not (c is TCustomTreeView)) and
       (not (c is TCustomComboBox)) then
      WalkControls(TWinControl(c));
  end;
end;

procedure ScaleFormForFont(form: TCustomForm; oldTH, newTH: integer);
var
  fromPPI, toPPI, newWidth: integer;
begin
  if (oldTH<=0) or (newTH<=0) or (oldTH=newTH) then exit;

  //express the font growth as a DPI change and let the LCL do the work
  fromPPI:=96;
  toPPI:=round(96 * (newTH / oldTH));
  if toPPI=fromPPI then exit;

  //AutoSize controls grow by their caption, not by the font ratio, and a
  //translated caption grows more still: "Ajustes" against "Settings" pushed
  //the logo panel past the right edge. The slack absorbs that.
  newWidth:=round(form.Width * (newTH / oldTH) * ModernMetrics.WidthSlack);
  form.AutoAdjustLayout(lapAutoAdjustForDPI, fromPPI, toPPI, form.Width, newWidth);
end;

procedure ApplyModernUI(form: TCustomForm);
var
  oldTH, newTH: integer;
  hook: TShowHook;
begin
  if not ModernMetrics.Enabled then exit;
  if form=nil then exit;

  oldTH:=TextHeightFor(form.Font);

  //the .lfm files almost never pin Font.Height (41 occurrences across 164
  //files), so setting it on the form propagates through ParentFont
  form.Font.Name:=ModernMetrics.FontName;
  form.Font.Size:=ModernMetrics.FontSize;

  newTH:=TextHeightFor(form.Font);

  if ModernMetrics.ScaleForms then
    ScaleFormForFont(form, oldTH, newTH);

  WalkControls(form);

  //lightening the captions only makes sense against a dark form; on a light
  //one it would make them unreadable the other way round
  if ModernMetrics.CustomDraw and ModernMetrics.DarkMode then
  begin
    form.Font.Color:=ModernMetrics.Text;
    SwapTextColors(form);
  end;

  hook:=TShowHook.Create;
  hook.original:=form.OnShow;
  form.OnShow:=@hook.Show;
end;

procedure InitSettings;
var
  i: integer;
  p: string;
begin
  ModernMetrics.Enabled:=true;

  //bundled first, Windows fonts only if they could not be registered
  if UIFontLoaded then
    ModernMetrics.FontName:=UIFontFamily
  else
    ModernMetrics.FontName:='Segoe UI';
  ModernMetrics.FontSize:=9;
  ModernMetrics.EditHeight:=26;
  ModernMetrics.ButtonHeight:=28;
  ModernMetrics.ToggleHeight:=22;
  ModernMetrics.Spacing:=3;
  ModernMetrics.CornerRadius:=6;
  ModernMetrics.ScaleForms:=true;
  ModernMetrics.WidthSlack:=1.10;
  ModernMetrics.CustomDraw:=true;

  //TNewForm paints the form background $242424, so these sit just above it
  ModernMetrics.ButtonFace:=$3A3A3A;
  ModernMetrics.ButtonFaceHover:=$464646;
  ModernMetrics.ButtonFaceDown:=$2E2E2E;
  ModernMetrics.ButtonFaceDisabled:=$2B2B2B;
  ModernMetrics.ButtonBorder:=$4D4D4D;
  ModernMetrics.ButtonBorderHover:=$6E6E6E;
  //the palette has to carry its own foreground: ColorSet.FontColor comes from
  //the Windows visual theme, and anywhere that theme is light (Wine, or a
  //machine in light mode) the text ends up black on a dark form
  ModernMetrics.Text:=$E0E0E0;
  ModernMetrics.TextDisabled:=$6E6E6E;
  ModernMetrics.GroupBoxBorder:=$4D4D4D;

  //betterControls fills the check box $e8e8e8, a near-white square that stands
  //out badly on the dark form. Dark fill with a light border and tick instead.
  ModernMetrics.CheckboxFill:=$2B2B2B;
  ModernMetrics.CheckboxMark:=$C8C8C8;
  ModernMetrics.CheckboxFillDisabled:=$242424;
  ModernMetrics.Accent:=$B09A2E;        //#2E9AB0, turquesa del logo
  ModernMetrics.AccentText:=$FFFFFF;
  ModernMetrics.MenuBackground:=$2B2B2B;
  ModernMetrics.MenuBarBackground:=$313131;
  ModernMetrics.MenuSeparator:=$4D4D4D;

  if MonoFontLoaded then
    ModernMetrics.MonoFontName:=MonoFontFamily
  else
    ModernMetrics.MonoFontName:='Consolas';   //ships with Windows since Vista
  ModernMetrics.ModernIcons:=true;
  ModernMetrics.ModernAbout:=true;

  for i:=1 to ParamCount do
  begin
    p:=uppercase(ParamStr(i));
    if (p='MODERNUI=0') or (p='NOMODERNUI') then
      ModernMetrics.Enabled:=false;
    if p='NOSCALEFORMS' then
      ModernMetrics.ScaleForms:=false;
    if p='NOROUNDING' then
      ModernMetrics.CornerRadius:=0;
    if p='NOCUSTOMDRAW' then
      ModernMetrics.CustomDraw:=false;
    if p='NOMODERNICONS' then
      ModernMetrics.ModernIcons:=false;
    if p='NOMODERNABOUT' then
      ModernMetrics.ModernAbout:=false;
  end;
end;

initialization
  InitSettings;

end.
