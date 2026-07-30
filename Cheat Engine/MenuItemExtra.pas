unit MenuItemExtra;

{$MODE Delphi}

{
V1.0: TMenuItemExtra is just a TMenuItem with an extra data pointer, so menu
items can be created on the fly and assigned extra data in the form of records
or other objects useful for an onclick handler
}

interface

uses menus, betterControls,
  {$if not defined(windows) and not defined(darwin) and not defined(jni)}linuxmemoryapi{$endif};

type TMenuItemExtra=class(TMenuItem)
  public
    data: pointer;
end;

implementation

end.
