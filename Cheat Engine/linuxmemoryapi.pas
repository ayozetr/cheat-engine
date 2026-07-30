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
  Classes, SysUtils, BaseUnix, Unix, ctypes;

const
  //declared up here because the snapshot records size their name buffers with
  //them, the same way the Windows headers do
  MAX_PATH = 260;
  MAX_MODULE_NAME32 = 255;

type
  //Windows spells its 32-bit boolean BOOL, and Cheat Engine declares whole
  //families of function types against it. Plain boolean is enough here since
  //nothing crosses a real Windows ABI boundary on Linux.
  BOOL = boolean;
  ULONG_PTR = PtrUInt;
  LONG_PTR = PtrInt;
  LONG = longint;
  ULONG = cardinal;
  ULONG64 = QWord;
  //only the ones the RTL does not already provide: redefining BYTE or INT64
  //here is self reference, since Pascal is case insensitive
  ULONG32 = cardinal;
  LONG32 = longint;
  LONG64 = Int64;
  DWORD64 = QWord;
  PULONG64 = ^ULONG64;
  UINT = cardinal;
  USHORT = word;
  UCHAR = byte;
  HANDLE = THandle;
  HWND = THandle;
  HMODULE = THandle;
  HINST = THandle;
  LPVOID = Pointer;
  PVOID = Pointer;
  LPCSTR = PAnsiChar;
  LPSTR = PAnsiChar;
  LPCWSTR = PWideChar;
  LPWSTR = PWideChar;
  LPTSTR = PAnsiChar;
  LPCTSTR = PAnsiChar;
  TCHAR = AnsiChar;
  PTCHAR = PAnsiChar;
  LPLPVOID = ^Pointer;
  PULONG = ^ULONG;
  PUINT = ^UINT;
  PHANDLE = ^HANDLE;
  PDWORD64 = ^DWORD64;
  PULONG32 = ^ULONG32;
  PLONG32 = ^LONG32;
  PLONG64 = ^LONG64;
  PLONG = ^LONG;
  PUSHORT = ^USHORT;
  PUCHAR = ^UCHAR;
  PULONG_PTR = ^ULONG_PTR;
  PLONG_PTR = ^LONG_PTR;
  PUINT_PTR = ^UINT_PTR;
  PINT_PTR = ^INT_PTR;
  PHMODULE = ^HMODULE;
  HKEY = THandle;
  PHKEY = ^HKEY;
  PHWND = ^HWND;
  PPVOID = ^PVOID;
  PINT = ^longint;
  PSHORT = ^smallint;
  FARPROC = Pointer;
  TFarProc = FARPROC;
  WCHAR = WideChar;
  PWCHAR = PWideChar;
  LPBYTE = ^byte;
  LPDWORD = ^DWORD;
  LPWORD = ^word;
  LPINT = ^longint;
  LPLONG = ^longint;
  COLORREF = DWORD;
  ATOM = word;
  LCID = DWORD;
  LANGID = word;
  LARGE_INTEGER = Int64;
  TLargeInteger = Int64;
  WINBOOL = boolean;
  TFNThreadStartRoutine = function(lpParameter: Pointer): DWORD; stdcall;
  PFNThreadStartRoutine = TFNThreadStartRoutine;

  //asynchronous procedure calls and overlapped I/O have no Linux counterpart,
  //but the ultimap forms declare fields of these types
  PAPCFUNC = procedure(dwParam: ULONG_PTR); stdcall;
  TFNAPCProc = PAPCFUNC;

  OVERLAPPED = record
    Internal: ULONG_PTR;
    InternalHigh: ULONG_PTR;
    Offset: DWORD;
    OffsetHigh: DWORD;
    hEvent: THandle;
  end;
  TOverlapped = OVERLAPPED;
  POverlapped = ^OVERLAPPED;
  LPOVERLAPPED = ^OVERLAPPED;
  ULARGE_INTEGER = QWord;
  PLARGE_INTEGER = ^LARGE_INTEGER;
  SIZE_T = PtrUInt;   //Pascal is case insensitive, so this covers size_t too
  DWORD_PTR = PtrUInt;
  INT_PTR = PtrInt;
  UINT_PTR = PtrUInt;
  PDWORD_PTR = ^DWORD_PTR;
  PSIZE_T = ^SIZE_T;   //Pascal is case insensitive, so this covers size_t too
  ptrdiff_t = PtrInt;
  WPARAM = PtrUInt;
  LPARAM = PtrInt;
  LRESULT = PtrInt;

  //same shape VirtualQueryEx fills in on Windows, since callers read these
  //fields directly
  TMemoryBasicInformation = record
    BaseAddress: Pointer;
    AllocationBase: Pointer;
    AllocationProtect: DWORD;
    RegionSize: PtrUInt;
    State: DWORD;
    Protect: DWORD;
    _Type: DWORD;
  end;
  PMemoryBasicInformation = ^TMemoryBasicInformation;
  MEMORY_BASIC_INFORMATION = TMemoryBasicInformation;
  _MEMORY_BASIC_INFORMATION = TMemoryBasicInformation;
  PMEMORY_BASIC_INFORMATION = ^TMemoryBasicInformation;

  //XMM register: 16 bytes. Windows calls it M128A and NewKernelHandler uses
  //the name for the ARM vector registers too
  M128A = record
    Low: QWord;
    High: Int64;
  end;

  //NewKernelHandler declares these too, but inside {$ifdef windows}, so on
  //Linux they have to come from here. Same layout, so nothing downstream
  //has to know which side it got them from.
  XMM_SAVE_AREA32 = record
    ControlWord: WORD;
    StatusWord: WORD;
    TagWord: byte;
    Reserved1: byte;
    ErrorOpcode: WORD;
    ErrorOffset: DWORD;
    ErrorSelector: WORD;
    Reserved2: WORD;
    DataOffset: DWORD;
    DataSelector: WORD;
    Reserved3: WORD;
    MxCsr: DWORD;
    MxCsr_Mask: DWORD;
    FloatRegisters: array[0..7] of M128A;
    XmmRegisters: array[0..15] of M128A;
    Reserved4: array[0..95] of byte;
  end;
  _XMM_SAVE_AREA32 = XMM_SAVE_AREA32;
  TXmmSaveArea = XMM_SAVE_AREA32;
  PXmmSaveArea = ^TXmmSaveArea;

  //x86_64 thread context, in the Windows order. ptrace only fills the general
  //purpose half, but the record has to keep its shape: callers read FltSave.
  CONTEXT = packed record
    P1Home, P2Home, P3Home, P4Home, P5Home, P6Home: DWORD64;

    ContextFlags: DWORD;
    MxCsr: DWORD;

    SegCs, SegDs, SegEs, SegFs, SegGs, SegSs: WORD;
    EFlags: DWORD;

    Dr0, Dr1, Dr2, Dr3, Dr6, Dr7: DWORD64;

    Rax, Rcx, Rdx, Rbx, Rsp, Rbp, Rsi, Rdi: DWORD64;
    R8, R9, R10, R11, R12, R13, R14, R15: DWORD64;

    Rip: DWORD64;

    FltSave: XMM_SAVE_AREA32;

    VectorRegister: array[0..25] of M128A;
    VectorControl: DWORD64;

    DebugControl: DWORD64;
    LastBranchToRip: DWORD64;
    LastBranchFromRip: DWORD64;
    LastExceptionToRip: DWORD64;
    LastExceptionFromRip: DWORD64;
  end;
  TCONTEXT = CONTEXT;
  PCONTEXT = ^TCONTEXT;
  _CONTEXT = CONTEXT;

  TProcessEntry = record
    th32ProcessID: DWORD;
    th32ParentProcessID: DWORD;
    cntThreads: DWORD;
    //fixed buffers, not strings: callers all over the tree take the address of
    //element zero and hand it to pchar
    szExeFile: array[0..MAX_PATH-1] of char;
    //fields the Windows struct carries; kept so shared code compiles
    dwSize: DWORD;
    cntUsage: DWORD;
    th32DefaultHeapID: PtrUInt;
    th32ModuleID: DWORD;
    pcPriClassBase: longint;
    dwFlags: DWORD;
  end;

  TThreadEntry = record
    th32ThreadID: DWORD;
    th32OwnerProcessID: DWORD;
    dwSize: DWORD;
    cntUsage: DWORD;
    tpBasePri: longint;
    tpDeltaPri: longint;
    dwFlags: DWORD;
  end;

  TModuleEntry = record
    th32ProcessID: DWORD;
    modBaseAddr: Pointer;
    modBaseSize: PtrUInt;
    szModule: array[0..MAX_MODULE_NAME32] of char;
    szExePath: array[0..MAX_PATH-1] of char;
    dwSize: DWORD;
    th32ModuleID: DWORD;
    GlblcntUsage: DWORD;
    ProccntUsage: DWORD;
    hModule: THandle;
  end;

  //WaitForDebugEvent's payload. ptrace reports the same events through
  //waitpid status words, so the debugger keeps one shape to read from.
  TExceptionRecord = record
    ExceptionCode: DWORD;
    ExceptionFlags: DWORD;
    ExceptionRecord: Pointer;
    ExceptionAddress: Pointer;
    NumberParameters: DWORD;
    ExceptionInformation: array[0..14] of PtrUInt;
  end;
  PExceptionRecord = ^TExceptionRecord;
  EXCEPTION_RECORD = TExceptionRecord;

  TExceptionDebugInfo = record
    ExceptionRecord: TExceptionRecord;
    dwFirstChance: DWORD;
  end;

  TCreateThreadDebugInfo = record
    hThread: THandle;
    lpThreadLocalBase: Pointer;
    lpStartAddress: Pointer;
  end;

  TCreateProcessDebugInfo = record
    hFile: THandle;
    hProcess: THandle;
    hThread: THandle;
    lpBaseOfImage: Pointer;
    dwDebugInfoFileOffset: DWORD;
    nDebugInfoSize: DWORD;
    lpThreadLocalBase: Pointer;
    lpStartAddress: Pointer;
    lpImageName: Pointer;
    fUnicode: word;
  end;

  TExitThreadDebugInfo = record dwExitCode: DWORD; end;
  TExitProcessDebugInfo = record dwExitCode: DWORD; end;

  TLoadDLLDebugInfo = record
    hFile: THandle;
    lpBaseOfDll: Pointer;
    dwDebugInfoFileOffset: DWORD;
    nDebugInfoSize: DWORD;
    lpImageName: Pointer;
    fUnicode: word;
  end;

  TUnloadDLLDebugInfo = record lpBaseOfDll: Pointer; end;

  TOutputDebugStringInfo = record
    lpDebugStringData: PChar;
    fUnicode: word;
    nDebugStringLength: word;
  end;

  TRIPInfo = record
    dwError: DWORD;
    dwType: DWORD;
  end;

  TDebugEvent = record
    dwDebugEventCode: DWORD;
    dwProcessId: DWORD;
    dwThreadId: DWORD;
    case integer of
      0: (Exception: TExceptionDebugInfo);
      1: (CreateThread: TCreateThreadDebugInfo);
      2: (CreateProcessInfo: TCreateProcessDebugInfo);
      3: (ExitThread: TExitThreadDebugInfo);
      4: (ExitProcess: TExitProcessDebugInfo);
      5: (LoadDll: TLoadDLLDebugInfo);
      6: (UnloadDll: TUnloadDLLDebugInfo);
      7: (DebugString: TOutputDebugStringInfo);
      8: (RipInfo: TRIPInfo);
  end;
  PDebugEvent = ^TDebugEvent;
  DEBUG_EVENT = TDebugEvent;
  LPDEBUG_EVENT = ^TDebugEvent;
  _DEBUG_EVENT = TDebugEvent;
  PDEBUG_EVENT = ^TDebugEvent;

  PBOOL = ^BOOL;
  PWINBOOL = ^WINBOOL;

  //the names NewKernelHandler declares its function types against
  PProcessEntry32 = ^TProcessEntry;
  PThreadEntry32 = ^TThreadEntry;
  PModuleEntry32 = ^TModuleEntry;
  TProcessEntry32 = TProcessEntry;
  TThreadEntry32 = TThreadEntry;
  TModuleEntry32 = TModuleEntry;
  PROCESSENTRY32 = TProcessEntry;
  THREADENTRY32 = TThreadEntry;
  MODULEENTRY32 = TModuleEntry;

const
  INVALID_HANDLE_VALUE = THandle(-1);

  GENERIC_READ = $80000000;
  GENERIC_WRITE = $40000000;
  FILE_SHARE_READ = $00000001;
  FILE_SHARE_WRITE = $00000002;
  FILE_SHARE_DELETE = $00000004;
  FILE_FLAG_SEQUENTIAL_SCAN = $08000000;
  FILE_FLAG_RANDOM_ACCESS = $10000000;
  FILE_FLAG_OVERLAPPED = $40000000;
  FILE_FLAG_NO_BUFFERING = $20000000;
  FILE_FLAG_WRITE_THROUGH = DWORD($80000000);
  FILE_ATTRIBUTE_DIRECTORY = $10;
  FILE_BEGIN = 0;
  FILE_CURRENT = 1;
  FILE_END = 2;
  OPEN_EXISTING = 3;
  CREATE_ALWAYS = 2;
  FILE_ATTRIBUTE_NORMAL = $80;
  FILE_MAP_COPY = 1;
  FILE_MAP_READ = 4;
  FILE_MAP_WRITE = 2;
  PAGE_WRITECOPY = 8;
  TH32CS_SNAPPROCESS = $00000002;
  TH32CS_SNAPTHREAD  = $00000004;
  TH32CS_SNAPMODULE  = $00000008;
  TH32CS_SNAPMODULE32 = $00000010;
  TH32CS_SNAPALL = $0000000F;

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
  PAGE_EXECUTE_WRITECOPY = 128;
  PAGE_GUARD = $100;
  PAGE_NOCACHE = $200;
  PAGE_WRITECOMBINE = $400;

  MEM_IMAGE = $1000000;
  MEM_RESET = $80000;
  MEM_TOP_DOWN = $100000;
  MEM_DECOMMIT = $4000;
  MEM_RELEASE = $8000;
  MEM_LARGE_PAGES = $20000000;

  //winsock spells the failed-socket sentinel this way; on Unix it is just -1
  INVALID_SOCKET = -1;
  SOCKET_ERROR = -1;
  INADDR_ANY = 0;
  INADDR_BROADCAST = DWORD($FFFFFFFF);
  INADDR_LOOPBACK = $7F000001;
  INADDR_NONE = DWORD($FFFFFFFF);

  //debug event codes, as WaitForDebugEvent reports them
  EXCEPTION_DEBUG_EVENT = 1;
  CREATE_THREAD_DEBUG_EVENT = 2;
  CREATE_PROCESS_DEBUG_EVENT = 3;
  EXIT_THREAD_DEBUG_EVENT = 4;
  EXIT_PROCESS_DEBUG_EVENT = 5;
  LOAD_DLL_DEBUG_EVENT = 6;
  UNLOAD_DLL_DEBUG_EVENT = 7;
  OUTPUT_DEBUG_STRING_EVENT = 8;
  RIP_EVENT = 9;

  DBG_CONTINUE = $00010002;
  DBG_EXCEPTION_NOT_HANDLED = $80010001;
  DBG_TERMINATE_THREAD = $40010003;
  DBG_TERMINATE_PROCESS = $40010004;
  DBG_CONTROL_C = $40010005;
  DBG_CONTROL_BREAK = $40010008;

  EXCEPTION_ACCESS_VIOLATION = $C0000005;
  EXCEPTION_BREAKPOINT = $80000003;
  EXCEPTION_SINGLE_STEP = $80000004;
  EXCEPTION_GUARD_PAGE = $80000001;
  EXCEPTION_ILLEGAL_INSTRUCTION = $C000001D;
  EXCEPTION_STACK_OVERFLOW = $C00000FD;
  EXCEPTION_INT_DIVIDE_BY_ZERO = $C0000094;
  STATUS_SINGLE_STEP = $80000004;
  STATUS_BREAKPOINT = $80000003;
  //the WOW64 variants, reported when a 32 bit process stops under a 64 bit debugger
  STATUS_WX86_SINGLE_STEP = $4000001E;
  STATUS_WX86_BREAKPOINT = $4000001F;
  EXCEPTION_PRIV_INSTRUCTION = $C0000096;
  EXCEPTION_ARRAY_BOUNDS_EXCEEDED = $C000008C;
  EXCEPTION_DATATYPE_MISALIGNMENT = $80000002;
  EXCEPTION_FLT_DIVIDE_BY_ZERO = $C000008E;
  EXCEPTION_IN_PAGE_ERROR = $C0000006;
  EXCEPTION_INT_OVERFLOW = $C0000095;
  EXCEPTION_INVALID_DISPOSITION = $C0000026;
  EXCEPTION_NONCONTINUABLE_EXCEPTION = $C0000025;

  //which halves of CONTEXT a Get/SetThreadContext call is asking about
  CONTEXT_AMD64 = $00100000;
  CONTEXT_CONTROL = CONTEXT_AMD64 or $00000001;
  CONTEXT_INTEGER = CONTEXT_AMD64 or $00000002;
  CONTEXT_SEGMENTS = CONTEXT_AMD64 or $00000004;
  CONTEXT_FLOATING_POINT = CONTEXT_AMD64 or $00000008;
  CONTEXT_DEBUG_REGISTERS = CONTEXT_AMD64 or $00000010;
  CONTEXT_EXTENDED_REGISTERS = 0;
  CONTEXT_XSTATE = CONTEXT_AMD64 or $00000040;
  CONTEXT_FULL = CONTEXT_CONTROL or CONTEXT_INTEGER or CONTEXT_FLOATING_POINT;
  CONTEXT_ALL = CONTEXT_CONTROL or CONTEXT_INTEGER or CONTEXT_SEGMENTS or
                CONTEXT_FLOATING_POINT or CONTEXT_DEBUG_REGISTERS;

  //registry roots; the FPC Registry unit maps them onto files under the home
  //directory, so the syntax highlighter keeps its colour settings
  HKEY_CLASSES_ROOT = THandle($80000000);
  HKEY_CURRENT_USER = THandle($80000001);
  HKEY_LOCAL_MACHINE = THandle($80000002);
  HKEY_USERS = THandle($80000003);
  HKEY_CURRENT_CONFIG = THandle($80000005);

  //RegisterHotkey's modifier bits, which the hotkey editor displays
  MOD_ALT = 1;
  MOD_CONTROL = 2;
  MOD_SHIFT = 4;
  MOD_WIN = 8;

  //ShowWindow / ShellExecute show commands
  SW_HIDE = 0;
  SW_SHOWNORMAL = 1;
  SW_NORMAL = 1;
  SW_SHOWMINIMIZED = 2;
  SW_SHOWMAXIMIZED = 3;
  SW_MAXIMIZE = 3;
  SW_SHOWNOACTIVATE = 4;
  SW_SHOW = 5;
  SW_MINIMIZE = 6;
  SW_RESTORE = 9;

  //SetWindowPos, and the WinHelp command the help menu passes
  HWND_TOP = 0;
  HWND_BOTTOM = 1;
  HWND_TOPMOST = THandle(-1);
  HWND_NOTOPMOST = THandle(-2);
  SWP_NOSIZE = $0001;
  SWP_NOMOVE = $0002;
  SWP_NOZORDER = $0004;
  SWP_NOACTIVATE = $0010;
  SWP_SHOWWINDOW = $0040;
  SWP_HIDEWINDOW = $0080;
  HELP_CONTEXT = 1;
  HELP_QUIT = 2;
  HELP_CONTENTS = 3;

  //MessageBox flags and results. LCLType declares these too and the values
  //agree, so whichever unit comes last in a uses clause is equally correct.
  MB_OK = 0;
  MB_OKCANCEL = 1;
  MB_ABORTRETRYIGNORE = 2;
  MB_YESNOCANCEL = 3;
  MB_YESNO = 4;
  MB_RETRYCANCEL = 5;
  MB_ICONHAND = $10;
  MB_ICONERROR = $10;
  MB_ICONQUESTION = $20;
  MB_ICONEXCLAMATION = $30;
  MB_ICONWARNING = $30;
  MB_ICONASTERISK = $40;
  MB_ICONINFORMATION = $40;
  MB_DEFBUTTON1 = 0;
  MB_DEFBUTTON2 = $100;
  MB_SYSTEMMODAL = $1000;
  MB_TOPMOST = $40000;

  IDOK = 1;
  IDCANCEL = 2;
  IDABORT = 3;
  IDRETRY = 4;
  IDIGNORE = 5;
  IDYES = 6;
  IDNO = 7;

  //thread and process access rights; nothing checks them on Linux
  THREAD_ALL_ACCESS = $1FFFFF;
  THREAD_TERMINATE = $0001;
  THREAD_SUSPEND_RESUME = $0002;
  THREAD_GET_CONTEXT = $0008;
  THREAD_SET_CONTEXT = $0010;
  THREAD_QUERY_INFORMATION = $0040;
  THREAD_SET_INFORMATION = $0020;
  PROCESS_TERMINATE = $0001;
  PROCESS_CREATE_THREAD = $0002;
  PROCESS_VM_OPERATION = $0008;
  PROCESS_VM_READ = $0010;
  PROCESS_VM_WRITE = $0020;
  PROCESS_QUERY_INFORMATION = $0400;
  PROCESS_ALL_ACCESS = $1FFFFF;
  SYNCHRONIZE = $00100000;
  INFINITE = DWORD($FFFFFFFF);
  WAIT_OBJECT_0 = 0;
  WAIT_TIMEOUT = $102;
  WAIT_FAILED = DWORD($FFFFFFFF);

  //the handful of Windows error codes the tree compares against
  NO_ERROR = 0;
  ERROR_SUCCESS = 0;
  ERROR_FILE_NOT_FOUND = 2;
  ERROR_PATH_NOT_FOUND = 3;
  ERROR_ACCESS_DENIED = 5;
  ERROR_INVALID_HANDLE = 6;
  ERROR_NOT_ENOUGH_MEMORY = 8;
  ERROR_OUTOFMEMORY = 14;
  ERROR_INVALID_PARAMETER = 87;
  ERROR_PARTIAL_COPY = 299;

function OpenProcess(dwDesiredAccess: DWORD; bInheritHandle: boolean;
  dwProcessId: DWORD): THandle;
function CloseHandle(hObject: THandle): boolean;
//DBK32functions declares this for Windows; here the handle is a pid, so the
//question is simply whether that process is still around
function IsValidHandle(hProcess: THandle): boolean;

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

function GetCurrentProcessId: DWORD;
function GetCurrentProcess: THandle;
//no global keyboard state outside a display server connection
function GetAsyncKeyState(vKey: longint): smallint;

function OpenThread(dwDesiredAccess: DWORD; bInheritHandle: boolean;
  dwThreadId: DWORD): THandle;
function TerminateProcess(hProcess: THandle; uExitCode: DWORD): boolean;

//Windows reaches these through ntdll; here SIGSTOP and SIGCONT do the same job
function ntSuspendProcess(ProcessID: THandle): DWORD;
function ntResumeProcess(ProcessID: THandle): DWORD;

{
  Thread control and remote execution.

  These four have no Linux counterpart worth faking. Suspending one thread of
  another process needs ptrace and a stopped tracee; running code inside another
  process needs an injected stub. Neither is in place yet, so they report
  failure rather than pretend, and the callers already handle that: they are the
  paths behind "execute code in target process", which simply stays unavailable.
}
function SuspendThread(hThread: THandle): DWORD;
function ResumeThread(hThread: THandle): DWORD;
function GetExitCodeThread(hThread: THandle; var lpExitCode: DWORD): boolean;
function CreateRemoteThread(hProcess: THandle; lpThreadAttributes: Pointer;
  dwStackSize: DWORD; lpStartAddress: TFNThreadStartRoutine; lpParameter: Pointer;
  dwCreationFlags: DWORD; var lpThreadId: DWORD): THandle;
function WaitForSingleObject(hHandle: THandle; dwMilliseconds: DWORD): DWORD;

//part of the windows unit on Windows; every caller expects them in scope
procedure ZeroMemory(destination: Pointer; size: PtrUInt);
procedure CopyMemory(destination, source: Pointer; size: PtrUInt);
procedure MoveMemory(destination, source: Pointer; size: PtrUInt);
procedure FillMemory(destination: Pointer; size: PtrUInt; valor: byte);
procedure RtlZeroMemory(destination: Pointer; size: PtrUInt);
procedure RtlFillMemory(destination: Pointer; size: PtrUInt; valor: byte);
procedure RtlMoveMemory(destination, source: Pointer; size: PtrUInt);
procedure RtlCopyMemory(destination, source: Pointer; size: PtrUInt);
procedure OutputDebugString(const s: string);
procedure OutputDebugStringA(const s: string);

//Opens a document, folder or URL the way the desktop would. Windows uses this
//for both "open this link" and "run this program"; only the first sense has an
//equivalent here, and it is the one Cheat Engine actually asks for.
function ShellExecute(hWnd: THandle; Operation, FileName, Parameters,
  Directory: PChar; ShowCmd: longint): THandle;
//networkInterface only gets this from unixporthelper in the android build
procedure log(l: string);

//Memory mapped files. Windows splits this into open, create-a-mapping and
//map-a-view; POSIX does the whole thing with open and mmap, so the middle
//step just carries the file descriptor through.
function CreateFile(lpFileName: PChar; dwDesiredAccess, dwShareMode: DWORD;
  lpSecurityAttributes: Pointer; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
  hTemplateFile: THandle): THandle;
function CreateFileMapping(hFile: THandle; lpAttributes: Pointer;
  flProtect: DWORD; dwMaximumSizeHigh, dwMaximumSizeLow: DWORD;
  lpName: PChar): THandle;
function MapViewOfFile(hFileMappingObject: THandle; dwDesiredAccess: DWORD;
  dwFileOffsetHigh, dwFileOffsetLow: DWORD; dwNumberOfBytesToMap: PtrUInt): Pointer;
function UnmapViewOfFile(lpBaseAddress: Pointer): boolean;
function GetFileSize(hFile: THandle; lpFileSizeHigh: PDWORD): DWORD;
function GetFileSizeEx(hFile: THandle; lpFileSize: PLARGE_INTEGER): boolean;
//CreateFileW only differs in taking wide strings; nothing here cares
function CreateFileW(lpFileName: PWideChar; dwDesiredAccess, dwShareMode: DWORD;
  lpSecurityAttributes: Pointer; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
  hTemplateFile: THandle): THandle;
function GetLastError: DWORD;
procedure SetLastError(e: DWORD);

//anonymous mappings in our own address space; the tree uses these to build
//scratch buffers, not to touch the target process
function VirtualAlloc(lpAddress: Pointer; dwSize: PtrUInt;
  flAllocationType, flProtect: DWORD): Pointer;
function VirtualFree(lpAddress: Pointer; dwSize: PtrUInt; dwFreeType: DWORD): boolean;
function VirtualProtect(lpAddress: Pointer; dwSize: PtrUInt;
  flNewProtect: DWORD; var lpflOldProtect: DWORD): boolean;
//huge page size, straight out of /proc/meminfo
function GetLargePageMinimum: PtrUInt;
//macport exports this too, and the auto assembler aligns allocations with it
function getPageSize: PtrUInt;

implementation

type
  TIOVec = record
    iov_base: Pointer;
    iov_len: size_t;
  end;
  PIOVec = ^TIOVec;

//process_vm_readv and process_vm_writev are not wrapped by the FPC RTL, so
//they go through syscall directly, the same way ceserver reaches them
//the RTL does not wrap sysconf either
const _SC_PAGESIZE = 30;
function sysconf(name: cint): clong; cdecl; external 'c' name 'sysconf';

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

function IsValidHandle(hProcess: THandle): boolean;
begin
  result:=(hProcess<>0) and (hProcess<>INVALID_HANDLE_VALUE) and
          (FpKill(TPid(hProcess), 0)=0);
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
          lpBuffer._Type:=MEM_PRIVATE
        else
          lpBuffer._Type:=MEM_MAPPED;
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
  StrPLCopy(lppe.szExeFile, campos[2], MAX_PATH-1);
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
  StrPLCopy(lpme.szExePath, campos[2], MAX_PATH-1);
  StrPLCopy(lpme.szModule, ExtractFileName(campos[2]), MAX_MODULE_NAME32);
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

function GetAsyncKeyState(vKey: longint): smallint;
begin
  result:=0;
end;

function GetCurrentProcessId: DWORD;
begin
  result:=DWORD(FpGetpid);
end;

//Windows hands back a pseudo handle here; the pid serves the same purpose
function GetCurrentProcess: THandle;
begin
  result:=THandle(FpGetpid);
end;

function OpenThread(dwDesiredAccess: DWORD; bInheritHandle: boolean;
  dwThreadId: DWORD): THandle;
begin
  //same story as OpenProcess: the tid is the handle
  result:=THandle(dwThreadId);
end;

function ntSuspendProcess(ProcessID: THandle): DWORD;
begin
  if FpKill(TPid(ProcessID), SIGSTOP)=0 then
    result:=0
  else
    result:=DWORD(-1);
end;

function ntResumeProcess(ProcessID: THandle): DWORD;
begin
  if FpKill(TPid(ProcessID), SIGCONT)=0 then
    result:=0
  else
    result:=DWORD(-1);
end;

function SuspendThread(hThread: THandle): DWORD;
begin
  result:=DWORD(-1);
end;

function ResumeThread(hThread: THandle): DWORD;
begin
  result:=DWORD(-1);
end;

function GetExitCodeThread(hThread: THandle; var lpExitCode: DWORD): boolean;
begin
  lpExitCode:=0;
  result:=false;
end;

function CreateRemoteThread(hProcess: THandle; lpThreadAttributes: Pointer;
  dwStackSize: DWORD; lpStartAddress: TFNThreadStartRoutine; lpParameter: Pointer;
  dwCreationFlags: DWORD; var lpThreadId: DWORD): THandle;
begin
  lpThreadId:=0;
  result:=0;
end;

function WaitForSingleObject(hHandle: THandle; dwMilliseconds: DWORD): DWORD;
begin
  //nothing here hands out waitable kernel objects, so there is nothing to wait on
  result:=WAIT_FAILED;
end;

function TerminateProcess(hProcess: THandle; uExitCode: DWORD): boolean;
begin
  result:=FpKill(TPid(hProcess), SIGKILL)=0;
end;

procedure ZeroMemory(destination: Pointer; size: PtrUInt);
begin
  FillChar(destination^, size, 0);
end;

procedure CopyMemory(destination, source: Pointer; size: PtrUInt);
begin
  Move(source^, destination^, size);
end;

procedure FillMemory(destination: Pointer; size: PtrUInt; valor: byte);
begin
  FillChar(destination^, size, valor);
end;

procedure RtlZeroMemory(destination: Pointer; size: PtrUInt);
begin
  ZeroMemory(destination, size);
end;

procedure RtlFillMemory(destination: Pointer; size: PtrUInt; valor: byte);
begin
  FillMemory(destination, size, valor);
end;

procedure RtlMoveMemory(destination, source: Pointer; size: PtrUInt);
begin
  MoveMemory(destination, source, size);
end;

procedure RtlCopyMemory(destination, source: Pointer; size: PtrUInt);
begin
  CopyMemory(destination, source, size);
end;

function ShellExecute(hWnd: THandle; Operation, FileName, Parameters,
  Directory: PChar; ShowCmd: longint): THandle;
var
  destino, orden: ansistring;
begin
  result:=0;
  if FileName=nil then exit;
  destino:=FileName;
  if destino='' then exit;

  //single quotes so a path with spaces survives the shell
  orden:='xdg-open '''+StringReplace(destino, '''', '''\''''', [rfReplaceAll])+''' &';
  if fpSystem(orden)=0 then
    result:=42        //Windows returns >32 on success
  else
    result:=0;
end;

//stderr is the closest thing to a debug channel we have here
procedure OutputDebugString(const s: string);
begin
  writeln(stderr, s);
end;

procedure OutputDebugStringA(const s: string);
begin
  OutputDebugString(s);
end;

procedure log(l: string);
begin
  OutputDebugString(l);
end;

procedure MoveMemory(destination, source: Pointer; size: PtrUInt);
begin
  Move(source^, destination^, size);
end;

//--- memory mapped files ---------------------------------------------------

var
  //mmap needs the length at unmap time and Windows does not pass it, so the
  //size of each mapping is remembered here
  mapeos: array of record dir: Pointer; largo: PtrUInt; end;

function CreateFile(lpFileName: PChar; dwDesiredAccess, dwShareMode: DWORD;
  lpSecurityAttributes: Pointer; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
  hTemplateFile: THandle): THandle;
var
  banderas: cint;
  fd: cint;
begin
  if (dwDesiredAccess and GENERIC_WRITE)<>0 then
    banderas:=O_RDWR
  else
    banderas:=O_RDONLY;
  if dwCreationDisposition=CREATE_ALWAYS then
    banderas:=banderas or O_CREAT or O_TRUNC;

  fd:=FpOpen(lpFileName, banderas, &666);
  if fd<0 then
    result:=INVALID_HANDLE_VALUE
  else
    result:=THandle(fd);
end;

function CreateFileW(lpFileName: PWideChar; dwDesiredAccess, dwShareMode: DWORD;
  lpSecurityAttributes: Pointer; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
  hTemplateFile: THandle): THandle;
var
  nombre: ansistring;
begin
  nombre:=UTF8Encode(WideString(lpFileName));
  result:=CreateFile(PChar(nombre), dwDesiredAccess, dwShareMode,
    lpSecurityAttributes, dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile);
end;

function GetFileSizeEx(hFile: THandle; lpFileSize: PLARGE_INTEGER): boolean;
var
  info: stat;
begin
  result:=FpFStat(cint(hFile), info)=0;
  if lpFileSize<>nil then
  begin
    if result then
      lpFileSize^:=info.st_size
    else
      lpFileSize^:=0;
  end;
end;

//errno is the closest equivalent, and it is what the failing calls above set
function GetLastError: DWORD;
begin
  result:=DWORD(fpgeterrno);
end;

procedure SetLastError(e: DWORD);
begin
  fpseterrno(cint(e));
end;


function CreateFileMapping(hFile: THandle; lpAttributes: Pointer;
  flProtect: DWORD; dwMaximumSizeHigh, dwMaximumSizeLow: DWORD;
  lpName: PChar): THandle;
begin
  //POSIX has no separate mapping object: the descriptor is enough
  result:=hFile;
end;

function MapViewOfFile(hFileMappingObject: THandle; dwDesiredAccess: DWORD;
  dwFileOffsetHigh, dwFileOffsetLow: DWORD; dwNumberOfBytesToMap: PtrUInt): Pointer;
var
  prot, flags: cint;
  largo: PtrUInt;
  info: stat;
  n: integer;
begin
  result:=nil;
  largo:=dwNumberOfBytesToMap;
  if largo=0 then
  begin
    //zero means the whole file on Windows
    if FpFStat(cint(hFileMappingObject), info)<>0 then exit;
    largo:=info.st_size;
  end;
  if largo=0 then exit;

  prot:=PROT_READ;
  if (dwDesiredAccess and (FILE_MAP_WRITE or FILE_MAP_COPY))<>0 then
    prot:=prot or PROT_WRITE;

  if (dwDesiredAccess and FILE_MAP_COPY)<>0 then
    flags:=MAP_PRIVATE      //copy on write, which is what WRITECOPY means
  else
    flags:=MAP_SHARED;

  result:=FpMmap(nil, largo, prot, flags, cint(hFileMappingObject),
                 (QWord(dwFileOffsetHigh) shl 32) or dwFileOffsetLow);
  if result=Pointer(-1) then exit(nil);

  n:=Length(mapeos);
  SetLength(mapeos, n+1);
  mapeos[n].dir:=result;
  mapeos[n].largo:=largo;
end;

//Windows page protection bits translated to the mmap ones
function ProtToMmap(flProtect: DWORD): cint;
begin
  case flProtect and $FF of
    PAGE_NOACCESS: result:=PROT_NONE;
    PAGE_READONLY: result:=PROT_READ;
    PAGE_READWRITE, PAGE_WRITECOPY: result:=PROT_READ or PROT_WRITE;
    PAGE_EXECUTE: result:=PROT_EXEC;
    PAGE_EXECUTE_READ: result:=PROT_READ or PROT_EXEC;
    PAGE_EXECUTE_READWRITE, PAGE_EXECUTE_WRITECOPY:
      result:=PROT_READ or PROT_WRITE or PROT_EXEC;
  else
    result:=PROT_READ or PROT_WRITE;
  end;
end;

function VirtualAlloc(lpAddress: Pointer; dwSize: PtrUInt;
  flAllocationType, flProtect: DWORD): Pointer;
var
  n: integer;
begin
  result:=nil;
  if dwSize=0 then exit;

  result:=FpMmap(lpAddress, dwSize, ProtToMmap(flProtect),
                 MAP_PRIVATE or MAP_ANONYMOUS, -1, 0);
  if result=Pointer(-1) then exit(nil);

  //VirtualFree is allowed to pass zero for the size, so it has to be
  //remembered here, the same way MapViewOfFile does
  n:=Length(mapeos);
  SetLength(mapeos, n+1);
  mapeos[n].dir:=result;
  mapeos[n].largo:=dwSize;
end;

function VirtualFree(lpAddress: Pointer; dwSize: PtrUInt; dwFreeType: DWORD): boolean;
var
  i: integer;
  largo: PtrUInt;
begin
  result:=false;
  largo:=dwSize;
  for i:=0 to High(mapeos) do
    if mapeos[i].dir=lpAddress then
    begin
      if largo=0 then largo:=mapeos[i].largo;
      mapeos[i].dir:=nil;
      break;
    end;
  if largo=0 then exit;
  result:=FpMunmap(lpAddress, largo)=0;
end;

function VirtualProtect(lpAddress: Pointer; dwSize: PtrUInt;
  flNewProtect: DWORD; var lpflOldProtect: DWORD): boolean;
begin
  //mprotect gives no way to read the old value back, and no caller checks it
  lpflOldProtect:=PAGE_EXECUTE_READWRITE;
  result:=FpMProtect(lpAddress, dwSize, ProtToMmap(flNewProtect))=0;
end;

function getPageSize: PtrUInt;
begin
  result:=PtrUInt(sysconf(_SC_PAGESIZE));
  if result<=0 then result:=4096;
end;

function GetLargePageMinimum: PtrUInt;
var
  f: TextFile;
  linea: string;
begin
  result:=0;
  if not FileExists('/proc/meminfo') then exit;
  AssignFile(f, '/proc/meminfo');
  {$I-}Reset(f);{$I+}
  if IOResult<>0 then exit;
  try
    while not eof(f) do
    begin
      readln(f, linea);
      if Pos('Hugepagesize:', linea)=1 then
      begin
        //reported in kB
        linea:=Trim(Copy(linea, 14, Length(linea)));
        linea:=Trim(Copy(linea, 1, Pos(' ', linea+' ')-1));
        result:=StrToInt64Def(linea, 0)*1024;
        break;
      end;
    end;
  finally
    CloseFile(f);
  end;
end;

function UnmapViewOfFile(lpBaseAddress: Pointer): boolean;
var
  i: integer;
begin
  result:=false;
  for i:=0 to High(mapeos) do
    if mapeos[i].dir=lpBaseAddress then
    begin
      result:=FpMunmap(lpBaseAddress, mapeos[i].largo)=0;
      mapeos[i].dir:=nil;
      exit;
    end;
end;

function GetFileSize(hFile: THandle; lpFileSizeHigh: PDWORD): DWORD;
var
  info: stat;
begin
  if FpFStat(cint(hFile), info)<>0 then exit(DWORD(-1));
  if lpFileSizeHigh<>nil then
    lpFileSizeHigh^:=DWORD(QWord(info.st_size) shr 32);
  result:=DWORD(info.st_size and $FFFFFFFF);
end;


end.
