using module '..\..\3rdParty\PSReflect\PSReflect.psm1'

$Mod = New-InMemoryModule -ModuleName Win32

# $HKEY = psenum $Mod PE.IMAGE_SCN Int32 @{
#     LOCAL_MACHINE   = 0x80000002
#     USERS           = 0x80000003
# }


$ImageFileHeader = struct $Mod PE.IMAGE_FILE_HEADER @{
    Machine = field 0 $ImageFileMachine
    NumberOfSections = field 1 UInt16
    TimeDateStamp = field 2 UInt32
    PointerToSymbolTable = field 3 UInt32
    NumberOfSymbols = field 4 UInt32
    SizeOfOptionalHeader = field 5 UInt16
    Characteristics  = field 6 $ImageFileCharacteristics
}

$Types = $FunctionDefinitions | Add-Win32Type -Module $Mod -Namespace 'Win32'
$advapi32 = $Types['advapi32']


# [StructLayout(LayoutKind.Sequential)]
# public struct LUID
# {
# public int LowPart;
# public int HighPart;
# }
$LUID = struct $Mod advapi.LUID @{
    LowPart = field 0 Int32
    HighPart = field 1 Int32
}

# [StructLayout(LayoutKind.Sequential)]
# public struct TOKEN_PRIVILEGES
# {
# public LUID Luid;
# public int Attributes;
# public int PrivilegeCount;
# }
$TOKEN_PRIVILEGES = struct $Mod advapi.TOKEN_PRIVILEGES @{
    Luid = field 0 $LUID
    Attributes = field 1 Int32
    PrivilegeCount = field 2 Int32
}

# Private Declare Auto Function RegLoadKey Lib "advapi32.dll" ( _
#    ByVal hKey As IntPtr, _
#    ByVal lpSubKey As String, _
#    ByVal lpFile As String _
# ) As Integer

# all of the Win32 API functions we need
$FunctionDefinitions = @(
    (func advapi32 RegLoadKeyA ([Int32]) @([IntPtr], [String], [String]))
)


$mountKey = [System.Guid]::NewGuid().ToString()
$advapi32::RegLoadKeyA(2147483650, $mountKey, 'f:\Windows\System32\Config\System')
