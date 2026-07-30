unit memrecDataStructures;

{$mode delphi}

interface

uses
  Classes, SysUtils, autoassembler
  {$if not defined(windows) and not defined(darwin) and not defined(jni)}, linuxmemoryapi{$endif};

type
  TMemrecStringData=record
    unicode: boolean;
    codepage: boolean;
    length: integer;
    ZeroTerminate: boolean;
  end;

  TMemRecBitData=record
    Bit     : Byte;
    bitlength: integer;
    showasbinary: boolean;
  end;

  TMemRecByteData=record
    bytelength: integer;
  end;

  TMemRecAutoAssemblerData=record
    script: tstringlist;
    disableinfo: TDisableInfo;
    lastExecutionFailed: boolean;
    lastExecutionFailedReason: string;
  end;

  TMemRecExtraData=record
    case integer of
      1: (stringData: TMemrecStringData); //if this is the last level (maxlevel) this is an PPointerList
      2: (bitData: TMemRecBitData);   //else it's a PReversePointerListArray
      3: (byteData: TMemRecByteData);
  end;

implementation

end.

