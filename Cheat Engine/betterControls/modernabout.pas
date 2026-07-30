unit modernabout;

{
  Reworks the About window at runtime.

  aboutunit.lfm wraps the whole dialog in a group box whose caption doubles as
  the title, which is what makes it read as a nineties dialog: a frame around
  everything and a small caption. Rather than rewriting 687 lines of .lfm, the
  layout is adjusted once the form exists.

  Positions come from anchors rather than coordinates, since modernui has
  already rescaled the form for the larger font and the .lfm positions no
  longer hold.

  Pass NOMODERNABOUT to leave the original dialog alone.
}

{$mode objfpc}{$H+}

interface

uses
  {$ifdef windows}windows, shellapi,{$endif}
  Classes, SysUtils, Controls, Forms, Graphics, StdCtrls, ExtCtrls;

var
  //shown under the author line; empty hides it
  UICreditName: string = 'ayozetr';
  //a Ko-fi button next to Patreon; empty leaves the dialog with just Patreon
  UICreditKofi: string = 'https://ko-fi.com/ayozetr';

procedure ApplyModernAbout(form: TCustomForm);

implementation

uses modernui;

type
  //TAbout.FormShow is what fills the group box caption with the name and
  //version, so the rework has to run after it, not in the constructor
  TAboutHook = class
    original: TNotifyEvent;
    procedure Show(Sender: TObject);
    procedure KofiClick(Sender: TObject);
  end;

procedure Rework(form: TCustomForm; hook: TAboutHook); forward;

function FindLabel(form: TCustomForm; const name: string): TLabel;
var
  c: TComponent;
begin
  result:=nil;
  c:=form.FindComponent(name);
  if c is TLabel then result:=TLabel(c);
end;

procedure TAboutHook.KofiClick(Sender: TObject);
begin
  {$ifdef windows}
  ShellExecute(0, 'open', PChar(UICreditKofi), '', '', SW_SHOWNORMAL);
  {$endif}
end;

procedure TAboutHook.Show(Sender: TObject);
begin
  if original<>nil then original(Sender);
  if Sender is TCustomForm then Rework(TCustomForm(Sender), self);
end;

procedure Rework(form: TCustomForm; hook: TAboutHook);
var
  gb, logo, enlaces, patreon: TComponent;
  kofi: TButton;
  box: TGroupBox;
  titulo, credito, autor, tecnologia: TLabel;
  version: string;
begin
  //only once, even if the dialog is opened again
  if form.FindComponent('lblModernTitle')<>nil then exit;

  gb:=form.FindComponent('GroupBox1');
  if not (gb is TGroupBox) then exit;
  box:=TGroupBox(gb);

  credito:=nil;

  //FormShow puts the name and version in the group box caption. Keep the text
  //but move it to a real title, and drop the frame around the whole dialog.
  version:=box.Caption;
  box.Caption:='';

  logo:=form.FindComponent('Image1');
  autor:=FindLabel(form, 'Label1');       //"Creador: Dark Byte"
  enlaces:=form.FindComponent('Panel4');  //the two website links

  titulo:=TLabel.Create(form);
  titulo.Name:='lblModernTitle';
  titulo.Parent:=box;
  titulo.Caption:=version;
  titulo.Font.Name:=ModernMetrics.FontName;
  titulo.Font.Size:=ModernMetrics.FontSize+5;
  titulo.Font.Style:=[fsBold];
  titulo.Anchors:=[akLeft, akTop];

  if logo is TControl then
  begin
    //to the right of the logo, level with its top
    titulo.AnchorSideLeft.Control:=TControl(logo);
    titulo.AnchorSideLeft.Side:=asrBottom;
    titulo.AnchorSideTop.Control:=TControl(logo);
    titulo.BorderSpacing.Left:=14;
    titulo.BorderSpacing.Top:=2;
  end;

  //Credits stack under the title instead of trailing off to its right, so who
  //made what reads as one block: the author, then whoever did the interface.
  if autor<>nil then
  begin
    autor.AnchorSideLeft.Control:=titulo;
    autor.AnchorSideTop.Control:=titulo;
    autor.AnchorSideTop.Side:=asrBottom;
    autor.BorderSpacing.Top:=6;
    autor.Anchors:=[akLeft, akTop];
  end;

  if UICreditName<>'' then
  begin
    credito:=TLabel.Create(form);
    credito.Name:='lblModernCredit';
    credito.Parent:=box;
    credito.Caption:='Interfaz: '+UICreditName;
    credito.Font.Name:=ModernMetrics.FontName;
    credito.Font.Size:=ModernMetrics.FontSize;
    credito.Font.Style:=[fsBold];
    credito.Font.Color:=ModernMetrics.Accent;
    credito.Anchors:=[akLeft, akTop];

    //right under the author line and matching it, rather than tucked away at
    //the bottom in grey where it read as a footnote
    if autor<>nil then
    begin
      credito.AnchorSideLeft.Control:=autor;
      credito.AnchorSideTop.Control:=autor;
      credito.AnchorSideTop.Side:=asrBottom;
      credito.BorderSpacing.Top:=2;
    end
    else
    begin
      credito.AnchorSideLeft.Control:=titulo;
      credito.AnchorSideTop.Control:=titulo;
      credito.AnchorSideTop.Side:=asrBottom;
      credito.BorderSpacing.Top:=6;
    end;
  end;

  //the links sat level with the title; they belong under the credits.
  //Side has to be spelled out: for akLeft the default lines up with the
  //reference's right edge, which threw them off to the right.
  if (enlaces is TControl) and (credito<>nil) then
  begin
    TControl(enlaces).Anchors:=[akLeft, akTop];
    TControl(enlaces).AnchorSideLeft.Control:=titulo;
    TControl(enlaces).AnchorSideLeft.Side:=asrTop;
    TControl(enlaces).AnchorSideTop.Control:=credito;
    TControl(enlaces).AnchorSideTop.Side:=asrBottom;
    TControl(enlaces).BorderSpacing.Top:=6;

    //the block below started at a fixed Top and the taller header now runs
    //into it, so it follows the links instead
    tecnologia:=FindLabel(form, 'Label10');   //"Script engine powered by Lua"
    if tecnologia<>nil then
    begin
      tecnologia.Anchors:=[akLeft, akTop];
      tecnologia.AnchorSideLeft.Control:=box;
      tecnologia.AnchorSideLeft.Side:=asrTop;
      tecnologia.AnchorSideTop.Control:=TControl(enlaces);
      tecnologia.AnchorSideTop.Side:=asrBottom;
      tecnologia.BorderSpacing.Left:=6;
      tecnologia.BorderSpacing.Top:=10;
    end;
  end;

  //Patreon sits alone in its panel; Ko-fi goes beside it
  patreon:=form.FindComponent('Button2');
  if (patreon is TButton) and (UICreditKofi<>'') and (hook<>nil) then
  begin
    kofi:=TButton.Create(form);
    kofi.Name:='btnModernKofi';
    kofi.Parent:=TButton(patreon).Parent;
    kofi.Caption:='Ko-fi';
    kofi.OnClick:=@hook.KofiClick;
    kofi.Anchors:=[akLeft, akTop];
    kofi.AnchorSideLeft.Control:=TButton(patreon);
    kofi.AnchorSideLeft.Side:=asrTop;
    kofi.AnchorSideTop.Control:=TButton(patreon);
    kofi.AnchorSideTop.Side:=asrBottom;
    kofi.BorderSpacing.Top:=4;
    kofi.Width:=TButton(patreon).Width;
    kofi.Height:=TButton(patreon).Height;

    //without this the new button, being the last one created, takes the
    //initial focus and draws its focus frame, so it looks unlike its twin
    kofi.Font.Assign(TButton(patreon).Font);
    kofi.TabStop:=TButton(patreon).TabStop;
    kofi.TabOrder:=TButton(patreon).TabOrder+1;
  end;
end;

procedure ApplyModernAbout(form: TCustomForm);
var
  hook: TAboutHook;
begin
  if not ModernMetrics.ModernAbout then exit;
  if (form=nil) or (form.ClassName<>'TAbout') then exit;

  hook:=TAboutHook.Create;
  hook.original:=form.OnShow;
  form.OnShow:=@hook.Show;
end;

end.
