unit hypermode;

{$MODE Delphi}

{obsolete}

interface

uses classes,LCLIntf,sysutils,messages,
  {$if not defined(windows) and not defined(darwin) and not defined(jni)}linuxmemoryapi{$endif};

implementation

end.
