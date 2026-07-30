unit linuxmemoryapi;

{
  The Linux side of the memory access layer.

  NewKernelHandler is where every memory read, write and query in Cheat Engine
  ends up, and its uses clause only ever offered two branches: MacOSAll for
  darwin, jwawindows for everything else. On Linux that second branch does not
  exist, so nothing downstream could compile.

  This provides the handful of Windows functions NewKernelHandler expects, on
  top of the Linux equivalents:

      ReadProcessMemory   ->  process_vm_readv
      WriteProcessMemory  ->  process_vm_writev
      VirtualQueryEx      ->  /proc/<pid>/maps
      OpenProcess         ->  the pid itself, no kernel object involved

  The mapping is not invented here: ceserver, in this same repository, already
  does exactly this in C, and its api.c was the reference.

  A process handle is just the pid. Windows hands out an opaque kernel object
  and Linux does not need one, so the pid travels as the handle and the calls
  that would manage that object are no-ops that report success.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, BaseUnix, Unix;

type
  //same shape VirtualQueryEx fills in on Windows, since callers read these
  //fields directly
  TMemoryBasicInformation = record
    BaseAddress: Pointer;
    AllocationBase: Pointer;
    AllocationProtect: DWORD;
    RegionSize: PtrUInt;
    State: DWORD;
    Protect: DWORD;
    Type_9: DWORD;
  end;

  TProcessEntry = record
    th32ProcessID: DWORD;
    th32ParentProcessID: DWORD;
    cntThreads: DWORD;
    szExeFile: string;
  end;

  TThreadEntry = record
    th32ThreadID: DWORD;
    th32OwnerProcessID: DWORD;
  end;

  TModuleEntry = record
    th32ProcessID: DWORD;
    modBaseAddr: Pointer;
    modBaseSize: PtrUInt;
    szModule: string;
    szExePath: string;
  end;

const
  TH32CS_SNAPPROCESS = $00000002;
  TH32CS_SNAPTHREAD  = $00000004;
  TH32CS_SNAPMODULE  = $00000008;

  //the subset of the Windows constants the callers actually compare against
  MEM_COMMIT = $1000;
  MEM_FREE = $10000;
  MEM_RESERVE = $2000;
  MEM_PRIVATE = $20000;
  MEM_MAPPED = $40000;

  PAGE_NOACCESS = 1;
  PAGE_READONLY = 2;
  PAGE_READWRITE = 4;
  PAGE_EXECUTE = 16;
  PAGE_EXECUTE_READ = 32;
  PAGE_EXECUTE_READWRITE = 64;

function OpenProcess(dwDesiredAccess: DWORD; bInheritHandle: boolean;
  dwProcessId: DWORD): THandle;
function CloseHandle(hObject: THandle): boolean;

function ReadProcessMemory(hProcess: THandle; lpBaseAddress, lpBuffer: Pointer;
  nSize: PtrUInt; var lpNumberOfBytesRead: PtrUInt): boolean;
function WriteProcessMemory(hProcess: THandle; const lpBaseAddress: Pointer;
  lpBuffer: Pointer; nSize: PtrUInt; var lpNumberOfBytesWritten: PtrUInt): boolean;

function VirtualQueryEx(hProcess: THandle; lpAddress: Pointer;
  var lpBuffer: TMemoryBasicInformation; dwLength: DWORD): DWORD;

//Windows takes a snapshot and then walks it. /proc has no such notion, so the
//snapshot is taken literally: the listing is read once and iterated after.
function CreateToolhelp32Snapshot(dwFlags, th32ProcessID: DWORD): THandle;
function Process32First(hSnapshot: THandle; var lppe: TProcessEntry): boolean;
function Process32Next(hSnapshot: THandle; var lppe: TProcessEntry): boolean;
function Thread32First(hSnapshot: THandle; var lpte: TThreadEntry): boolean;
function Thread32Next(hSnapshot: THandle; var lpte: TThreadEntry): boolean;
function Module32First(hSnapshot: THandle; var lpme: TModuleEntry): boolean;
function Module32Next(hSnapshot: THandle; var lpme: TModuleEntry): boolean;
function CloseSnapshot(hSnapshot: THandle): boolean;

function OpenThread(dwDesiredAccess: DWORD; bInheritHandle: boolean;
  dwThreadId: DWORD): THandle;
function TerminateProcess(hProcess: THandle; uExitCode: DWORD): boolean;

implementation

type
  TIOVec = record
    iov_base: Pointer;
    iov_len: size_t;
  end;
  PIOVec = ^TIOVec;

//process_vm_readv and process_vm_writev are not wrapped by the FPC RTL, so
//they go through syscall directly, the same way ceserver reaches them
function process_vm_readv(pid: TPid; local_iov: PIOVec; liovcnt: culong;
  remote_iov: PIOVec; riovcnt: culong; flags: culong): ssize_t; cdecl;
  external 'c' name 'process_vm_readv';
function process_vm_writev(pid: TPid; local_iov: PIOVec; liovcnt: culong;
  remote_iov: PIOVec; riovcnt: culong; flags: culong): ssize_t; cdecl;
  external 'c' name 'process_vm_writev';


function OpenProcess(dwDesiredAccess: DWORD; bInheritHandle: boolean;
  dwProcessId: DWORD): THandle;
begin
  //no kernel object to open: the pid is the handle. Checking that the process
  //exists keeps the failure at the same point Windows would report it.
  if FpKill(dwProcessId, 0)=0 then
    result:=THandle(dwProcessId)
  else
    result:=0;
end;

function CloseHandle(hObject: THandle): boolean;
begin
  //nothing was opened, so nothing to close
  result:=true;
end;

function ReadProcessMemory(hProcess: THandle; lpBaseAddress, lpBuffer: Pointer;
  nSize: PtrUInt; var lpNumberOfBytesRead: PtrUInt): boolean;
var
  local, remote: TIOVec;
  r: ssize_t;
begin
  lpNumberOfBytesRead:=0;
  if (hProcess=0) or (nSize=0) then exit(false);

  local.iov_base:=lpBuffer;
  local.iov_len:=nSize;
  remote.iov_base:=lpBaseAddress;
  remote.iov_len:=nSize;

  r:=process_vm_readv(TPid(hProcess), @local, 1, @remote, 1, 0);
  if r<0 then exit(false);

  lpNumberOfBytesRead:=PtrUInt(r);
  result:=PtrUInt(r)=nSize;
end;

function WriteProcessMemory(hProcess: THandle; const lpBaseAddress: Pointer;
  lpBuffer: Pointer; nSize: PtrUInt; var lpNumberOfBytesWritten: PtrUInt): boolean;
var
  local, remote: TIOVec;
  r: ssize_t;
begin
  lpNumberOfBytesWritten:=0;
  if (hProcess=0) or (nSize=0) then exit(false);

  local.iov_base:=lpBuffer;
  local.iov_len:=nSize;
  remote.iov_base:=lpBaseAddress;
  remote.iov_len:=nSize;

  r:=process_vm_writev(TPid(hProcess), @local, 1, @remote, 1, 0);
  if r<0 then exit(false);

  lpNumberOfBytesWritten:=PtrUInt(r);
  result:=PtrUInt(r)=nSize;
end;

function ProtectFromMapsFlags(const flags: string): DWORD;
//maps spells permissions as rwxp; Windows uses one constant per combination
begin
  if Pos('x', flags)>0 then
  begin
    if Pos('w', flags)>0 then result:=PAGE_EXECUTE_READWRITE
    else if Pos('r', flags)>0 then result:=PAGE_EXECUTE_READ
    else result:=PAGE_EXECUTE;
  end
  else
  begin
    if Pos('w', flags)>0 then result:=PAGE_READWRITE
    else if Pos('r', flags)>0 then result:=PAGE_READONLY
    else result:=PAGE_NOACCESS;
  end;
end;

function VirtualQueryEx(hProcess: THandle; lpAddress: Pointer;
  var lpBuffer: TMemoryBasicInformation; dwLength: DWORD): DWORD;
var
  maps: TextFile;
  linea, rango, flags: string;
  ini, fin, dir, guionpos: PtrUInt;
  encontrado: boolean;
  anterior_fin: PtrUInt;
begin
  result:=0;
  if hProcess=0 then exit;

  FillChar(lpBuffer, sizeof(lpBuffer), 0);
  dir:=PtrUInt(lpAddress);
  encontrado:=false;
  anterior_fin:=0;

  AssignFile(maps, Format('/proc/%d/maps', [hProcess]));
  {$I-}
  Reset(maps);
  {$I+}
  if IOResult<>0 then exit;

  try
    while not Eof(maps) do
    begin
      ReadLn(maps, linea);
      if linea='' then continue;

      //format: 7f8e4c000000-7f8e4c021000 rw-p 00000000 00:00 0
      guionpos:=Pos('-', linea);
      if guionpos=0 then continue;
      rango:=Copy(linea, 1, guionpos-1);
      ini:=StrToQWordDef('$'+rango, 0);
      fin:=StrToQWordDef('$'+Copy(linea, guionpos+1, Pos(' ', linea)-guionpos-1), 0);
      if fin<=ini then continue;

      if (dir>=ini) and (dir<fin) then
      begin
        flags:=Copy(linea, Pos(' ', linea)+1, 4);
        lpBuffer.BaseAddress:=Pointer(ini);
        lpBuffer.AllocationBase:=Pointer(ini);
        lpBuffer.RegionSize:=fin-ini;
        lpBuffer.State:=MEM_COMMIT;
        lpBuffer.Protect:=ProtectFromMapsFlags(flags);
        lpBuffer.AllocationProtect:=lpBuffer.Protect;
        if Pos('p', flags)>0 then
          lpBuffer.Type_9:=MEM_PRIVATE
        else
          lpBuffer.Type_9:=MEM_MAPPED;
        encontrado:=true;
        break;
      end;

      //a gap before this region is free memory, which is what callers walking
      //the address space expect to be told about
      if (ini>dir) and (dir>=anterior_fin) then
      begin
        lpBuffer.BaseAddress:=Pointer(dir);
        lpBuffer.RegionSize:=ini-dir;
        lpBuffer.State:=MEM_FREE;
        lpBuffer.Protect:=PAGE_NOACCESS;
        encontrado:=true;
        break;
      end;

      anterior_fin:=fin;
    end;
  finally
    CloseFile(maps);
  end;

  if encontrado then
    result:=sizeof(TMemoryBasicInformation);
end;

//--- snapshots -------------------------------------------------------------
// Windows returns a handle to a frozen list; /proc has nothing like it, so the
// listing is read once into memory and the handle is an index into the
// snapshots we are holding.

type
  TSnapshot = class
    kind: DWORD;
    pid: DWORD;
    rows: TStringList;   //one line per entry, already parsed into fields
    cursor: integer;
    constructor Create;
    destructor Destroy; override;
  end;

var
  snapshots: TList = nil;

constructor TSnapshot.Create;
begin
  rows:=TStringList.Create;
  cursor:=-1;
end;

destructor TSnapshot.Destroy;
begin
  rows.Free;
  inherited;
end;

function LeerArchivo(const fn: string): string;
var
  f: TextFile;
  l: string;
begin
  result:='';
  AssignFile(f, fn);
  {$I-}
  Reset(f);
  {$I+}
  if IOResult<>0 then exit;
  try
    while not Eof(f) do
    begin
      ReadLn(f, l);
      result:=result+l+#10;
    end;
  finally
    CloseFile(f);
  end;
end;

function NombreProceso(pid: DWORD): string;
var
  s: string;
  i: integer;
begin
  //comm holds the short name; cmdline the full one when it is there
  s:=Trim(LeerArchivo(Format('/proc/%d/comm', [pid])));
  result:=s;
  s:=LeerArchivo(Format('/proc/%d/cmdline', [pid]));
  if s<>'' then
  begin
    i:=Pos(#0, s);
    if i>0 then s:=Copy(s, 1, i-1);
    s:=Trim(StringReplace(s, #10, '', [rfReplaceAll]));
    if s<>'' then result:=ExtractFileName(s);
  end;
end;

function CreateToolhelp32Snapshot(dwFlags, th32ProcessID: DWORD): THandle;
var
  snap: TSnapshot;
  info: TSearchRec;
  pid: DWORD;
  linea: string;
  maps: TStringList;
  i, guion: integer;
  ini, fin: PtrUInt;
  ruta, modulo: string;
begin
  if snapshots=nil then snapshots:=TList.Create;

  snap:=TSnapshot.Create;
  snap.kind:=dwFlags;
  snap.pid:=th32ProcessID;

  if (dwFlags and TH32CS_SNAPPROCESS)<>0 then
  begin
    //every numeric directory under /proc is a process
    if FindFirst('/proc/*', faDirectory, info)=0 then
    begin
      repeat
        pid:=StrToDWordDef(info.Name, 0);
        if pid>0 then
          snap.rows.Add(Format('%d|%d|%s', [pid, 0, NombreProceso(pid)]));
      until FindNext(info)<>0;
      FindClose(info);
    end;
  end
  else if (dwFlags and TH32CS_SNAPTHREAD)<>0 then
  begin
    //each thread of a process is a directory under task/
    if FindFirst(Format('/proc/%d/task/*', [th32ProcessID]), faDirectory, info)=0 then
    begin
      repeat
        pid:=StrToDWordDef(info.Name, 0);
        if pid>0 then
          snap.rows.Add(Format('%d|%d', [pid, th32ProcessID]));
      until FindNext(info)<>0;
      FindClose(info);
    end;
  end
  else if (dwFlags and TH32CS_SNAPMODULE)<>0 then
  begin
    //maps lists every mapped file; the first line of each is its base
    maps:=TStringList.Create;
    try
      maps.Text:=LeerArchivo(Format('/proc/%d/maps', [th32ProcessID]));
      for i:=0 to maps.Count-1 do
      begin
        linea:=maps[i];
        if Pos('/', linea)=0 then continue;         //anonymous mapping
        ruta:=Trim(Copy(linea, Pos('/', linea), Length(linea)));
        modulo:=ExtractFileName(ruta);
        if snap.rows.IndexOfName(modulo)>=0 then continue;   //already seen

        guion:=Pos('-', linea);
        if guion=0 then continue;
        ini:=StrToQWordDef('$'+Copy(linea, 1, guion-1), 0);
        fin:=StrToQWordDef('$'+Copy(linea, guion+1, Pos(' ', linea)-guion-1), 0);
        if fin<=ini then continue;

        snap.rows.Add(Format('%s=%d|%d|%s', [modulo, ini, fin-ini, ruta]));
      end;
    finally
      maps.Free;
    end;
  end;

  snapshots.Add(snap);
  result:=THandle(snapshots.Count);   //1-based so 0 stays invalid
end;

function DameSnapshot(h: THandle): TSnapshot;
begin
  result:=nil;
  if (snapshots=nil) or (h=0) or (h>THandle(snapshots.Count)) then exit;
  result:=TSnapshot(snapshots[h-1]);
end;

function CloseSnapshot(hSnapshot: THandle): boolean;
var
  snap: TSnapshot;
begin
  snap:=DameSnapshot(hSnapshot);
  result:=snap<>nil;
  if result then
  begin
    snapshots[hSnapshot-1]:=nil;   //index stays valid for the others
    snap.Free;
  end;
end;

function SiguienteProceso(snap: TSnapshot; var lppe: TProcessEntry): boolean;
var
  campos: TStringArray;
begin
  result:=false;
  if (snap=nil) or (snap.cursor>=snap.rows.Count) then exit;

  campos:=snap.rows[snap.cursor].Split('|');
  if Length(campos)<3 then exit;

  lppe.th32ProcessID:=StrToDWordDef(campos[0], 0);
  lppe.th32ParentProcessID:=StrToDWordDef(campos[1], 0);
  lppe.cntThreads:=0;
  lppe.szExeFile:=campos[2];
  result:=true;
end;

function Process32First(hSnapshot: THandle; var lppe: TProcessEntry): boolean;
var
  snap: TSnapshot;
begin
  snap:=DameSnapshot(hSnapshot);
  if snap=nil then exit(false);
  snap.cursor:=0;
  result:=SiguienteProceso(snap, lppe);
end;

function Process32Next(hSnapshot: THandle; var lppe: TProcessEntry): boolean;
var
  snap: TSnapshot;
begin
  snap:=DameSnapshot(hSnapshot);
  if snap=nil then exit(false);
  inc(snap.cursor);
  result:=SiguienteProceso(snap, lppe);
end;

function SiguienteHilo(snap: TSnapshot; var lpte: TThreadEntry): boolean;
var
  campos: TStringArray;
begin
  result:=false;
  if (snap=nil) or (snap.cursor>=snap.rows.Count) then exit;

  campos:=snap.rows[snap.cursor].Split('|');
  if Length(campos)<2 then exit;

  lpte.th32ThreadID:=StrToDWordDef(campos[0], 0);
  lpte.th32OwnerProcessID:=StrToDWordDef(campos[1], 0);
  result:=true;
end;

function Thread32First(hSnapshot: THandle; var lpte: TThreadEntry): boolean;
var
  snap: TSnapshot;
begin
  snap:=DameSnapshot(hSnapshot);
  if snap=nil then exit(false);
  snap.cursor:=0;
  result:=SiguienteHilo(snap, lpte);
end;

function Thread32Next(hSnapshot: THandle; var lpte: TThreadEntry): boolean;
var
  snap: TSnapshot;
begin
  snap:=DameSnapshot(hSnapshot);
  if snap=nil then exit(false);
  inc(snap.cursor);
  result:=SiguienteHilo(snap, lpte);
end;

function SiguienteModulo(snap: TSnapshot; var lpme: TModuleEntry): boolean;
var
  linea, valores: string;
  campos: TStringArray;
begin
  result:=false;
  if (snap=nil) or (snap.cursor>=snap.rows.Count) then exit;

  linea:=snap.rows[snap.cursor];
  valores:=Copy(linea, Pos('=', linea)+1, Length(linea));
  campos:=valores.Split('|');
  if Length(campos)<3 then exit;

  lpme.th32ProcessID:=snap.pid;
  lpme.modBaseAddr:=Pointer(StrToQWordDef(campos[0], 0));
  lpme.modBaseSize:=StrToQWordDef(campos[1], 0);
  lpme.szExePath:=campos[2];
  lpme.szModule:=ExtractFileName(campos[2]);
  result:=true;
end;

function Module32First(hSnapshot: THandle; var lpme: TModuleEntry): boolean;
var
  snap: TSnapshot;
begin
  snap:=DameSnapshot(hSnapshot);
  if snap=nil then exit(false);
  snap.cursor:=0;
  result:=SiguienteModulo(snap, lpme);
end;

function Module32Next(hSnapshot: THandle; var lpme: TModuleEntry): boolean;
var
  snap: TSnapshot;
begin
  snap:=DameSnapshot(hSnapshot);
  if snap=nil then exit(false);
  inc(snap.cursor);
  result:=SiguienteModulo(snap, lpme);
end;

function OpenThread(dwDesiredAccess: DWORD; bInheritHandle: boolean;
  dwThreadId: DWORD): THandle;
begin
  //same story as OpenProcess: the tid is the handle
  result:=THandle(dwThreadId);
end;

function TerminateProcess(hProcess: THandle; uExitCode: DWORD): boolean;
begin
  result:=FpKill(TPid(hProcess), SIGKILL)=0;
end;


end.
