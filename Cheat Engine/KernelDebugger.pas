unit KernelDebugger;

{obsolete}

{$MODE Delphi}

interface

uses classes, sysutils
  {$if not defined(windows) and not defined(darwin) and not defined(jni)}, linuxmemoryapi{$endif};


implementation

end.
