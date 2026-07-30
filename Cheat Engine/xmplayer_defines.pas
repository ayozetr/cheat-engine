unit xmplayer_defines;

{$mode delphi}

interface

uses
  Classes, SysUtils,
  {$if not defined(windows) and not defined(darwin) and not defined(jni)}linuxmemoryapi{$endif}; 


const XMPLAYER_PLAYXM = 0;
const XMPLAYER_PAUSE = 1;
const XMPLAYER_RESUME = 2;
const XMPLAYER_STOP = 3;
const XMPLAYER_SETVOLUME = 4;


implementation

end.

