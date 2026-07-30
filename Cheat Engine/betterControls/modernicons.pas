unit modernicons;

{
  Replaces image list icons at runtime from PNG files on disk.

  The toolbar glyphs live inside a TImageList embedded in MainUnit.lfm as a
  zlib blob, so they cannot be edited by hand. TCustomImageList.Replace lets
  us swap them once the form exists.

  Layout, relative to the images folder:

      images/modern/<image list name>/<index>_<size>.png
      images/modern/<image list name>/<index>.png      (fallback)

  An image list only accepts bitmaps of its own size, so the size suffix is
  matched against ImageList.Width rather than rescaling in code, which would
  lose the alpha channel. Indices without a file keep the original glyph, so
  the set can be filled in gradually.

  Pass NOMODERNICONS to keep the original ones.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Forms, Graphics, ImgList, Buttons, Menus;

procedure ApplyModernIcons(form: TCustomForm);

implementation

uses modernui;

function IconRoot: string;
var
  exeDir: string;
begin
  exeDir:=ExtractFilePath(ParamStr(0));

  //the executable sits in bin/ while images/ is next to it, one level up
  result:=exeDir+'images'+PathDelim+'modern'+PathDelim;
  if DirectoryExists(result) then exit;

  result:=exeDir+'..'+PathDelim+'images'+PathDelim+'modern'+PathDelim;
end;

procedure ReplaceIcons(il: TCustomImageList; const listName: string);
var
  i: integer;
  base, fn: string;
  png: TPortableNetworkGraphic;
begin
  if (il=nil) or (listName='') then exit;

  base:=IconRoot+listName+PathDelim;
  if not DirectoryExists(base) then exit;

  for i:=0 to il.Count-1 do
  begin
    fn:=base+IntToStr(i)+'_'+IntToStr(il.Width)+'.png';
    if not FileExists(fn) then
      fn:=base+IntToStr(i)+'.png';
    if not FileExists(fn) then continue;   //keep the original glyph

    png:=TPortableNetworkGraphic.Create;
    try
      try
        png.LoadFromFile(fn);
        if (png.Width=il.Width) and (png.Height=il.Height) then
          il.Replace(i, png, nil, true);
      except
        //a broken or missing file must never stop the form from opening
      end;
    finally
      png.Free;
    end;
  end;
end;

function FindIcon(const listName: string; index, size: integer): string;
var
  base: string;
  s: integer;
begin
  base:=IconRoot+listName+PathDelim+IntToStr(index)+'_';

  result:=base+IntToStr(size)+'.png';
  if FileExists(result) then exit;

  //buttons ask for sizes we may not have generated (ImageWidth is 21 on some
  //of them). Prefer the next size up, since shrinking looks better than
  //enlarging, and only then fall back to smaller ones.
  for s:=size+1 to 64 do
  begin
    result:=base+IntToStr(s)+'.png';
    if FileExists(result) then exit;
  end;

  for s:=size-1 downto 8 do
  begin
    result:=base+IntToStr(s)+'.png';
    if FileExists(result) then exit;
  end;

  result:=IconRoot+listName+PathDelim+IntToStr(index)+'.png';
  if not FileExists(result) then result:='';
end;

procedure ApplySpeedButtonGlyphs(parent: TWinControl);
var
  i, size: integer;
  c: TControl;
  sb: TCustomSpeedButton;
  fn: string;
  png: TPortableNetworkGraphic;
begin
  for i:=0 to parent.ControlCount-1 do
  begin
    c:=parent.Controls[i];

    if (c is TCustomSpeedButton) then
    begin
      sb:=TCustomSpeedButton(c);

      //mfImageList is 16x16, so a glyph taken from it gets stretched to the
      //button's ImageWidth of 23 and comes out blurry. Assigning the glyph
      //directly bypasses the image list and its fixed resolution.
      if (sb.Images<>nil) and (sb.ImageIndex>=0) then
      begin
        size:=sb.ImageWidth;
        if size<=0 then size:=24;

        fn:=FindIcon(sb.Images.Name, sb.ImageIndex, size);
        if fn<>'' then
        begin
          png:=TPortableNetworkGraphic.Create;
          try
            try
              png.LoadFromFile(fn);
              sb.Images:=nil;          //Images wins over Glyph, so clear it
              sb.Glyph.Assign(png);
            except
              //never let a bad file stop the form from opening
            end;
          finally
            png.Free;
          end;
        end;
      end;
    end;

    if c is TWinControl then
      ApplySpeedButtonGlyphs(TWinControl(c));
  end;
end;

//A handful of action entries in the main menus carry no ImageIndex at all, so
//they show a blank gap next to items that do have one. The rest of the
//entries without an index are check-marked options in context menus, where an
//icon does not belong, so only these are filled in.
procedure FillMissingMenuIcons(form: TCustomForm);

  procedure Assign(const compName: string; index: integer);
  var
    c: TComponent;
  begin
    c:=form.FindComponent(compName);
    if not (c is TMenuItem) then exit;
    if TMenuItem(c).ImageIndex>=0 then exit;   //leave the ones already set
    TMenuItem(c).ImageIndex:=index;
  end;

begin
  Assign('MenuItem9', 9);                    //generate trainer script: file-plus
  Assign('miTriggerAccessViolation', 22);    //test access violation: x-circle
  Assign('miTestAccessViolationThread', 22);
end;

procedure ApplyModernIcons(form: TCustomForm);
var
  i: integer;
  c: TComponent;
begin
  if not ModernMetrics.ModernIcons then exit;
  if form=nil then exit;

  FillMissingMenuIcons(form);

  //menus and other image list users still go through the list
  for i:=0 to form.ComponentCount-1 do
  begin
    c:=form.Components[i];
    if c is TCustomImageList then
      ReplaceIcons(TCustomImageList(c), c.Name);
  end;

  //buttons get the glyph straight, at full resolution
  ApplySpeedButtonGlyphs(form);
end;

end.
