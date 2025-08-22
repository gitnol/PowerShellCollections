#region P/Invoke Definitions

# Korrigierte C# Wrapper-Klasse für Everything3 SDK
$Everything3Type = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class Everything3SDK
{
    // Client connection functions
    [DllImport("Everything3_x64.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.StdCall)]
    public static extern IntPtr Everything3_ConnectW(string instanceName);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_DestroyClient(IntPtr client);

    // Search state functions
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern IntPtr Everything3_CreateSearchState();

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_DestroySearchState(IntPtr searchState);

    [DllImport("Everything3_x64.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_SetSearchTextW(IntPtr searchState, string searchText);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_SetSearchViewportOffset(IntPtr searchState, uint offset);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_SetSearchViewportCount(IntPtr searchState, uint count);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_SetSearchMatchCase(IntPtr searchState, bool matchCase);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_SetSearchMatchWholeWords(IntPtr searchState, bool matchWholeWords);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_SetSearchMatchPath(IntPtr searchState, bool matchPath);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_SetSearchRegex(IntPtr searchState, bool regex);

    // Search execution
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern IntPtr Everything3_Search(IntPtr client, IntPtr searchState);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_DestroyResultList(IntPtr resultList);

    // Result retrieval
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetResultListViewportCount(IntPtr resultList);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetResultListCount(IntPtr resultList);

    [DllImport("Everything3_x64.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetResultFullPathNameW(IntPtr resultList, uint index, StringBuilder fileName, uint fileNameSize);

    [DllImport("Everything3_x64.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetResultNameW(IntPtr resultList, uint index, StringBuilder fileName, uint fileNameSize);

    // Property requests
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_AddSearchPropertyRequest(IntPtr searchState, uint propertyId);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetResultPropertyTextW(IntPtr resultList, uint index, uint propertyId, StringBuilder buffer, uint bufferSize);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern ulong Everything3_GetResultPropertyUINT64(IntPtr resultList, uint index, uint propertyId);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetResultPropertyDWORD(IntPtr resultList, uint index, uint propertyId);

    // Sort functions
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_AddSearchSort(IntPtr searchState, uint propertyId, bool ascending);

    // Error handling
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetLastError();

    // Version info
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetMajorVersion(IntPtr client);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetMinorVersion(IntPtr client);

    // DB Status
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_IsDBLoaded(IntPtr client);
}

public static class Everything3Properties
{
    public const uint EVERYTHING3_PROPERTY_ID_NAME = 0;
    public const uint EVERYTHING3_PROPERTY_ID_PATH = 1;
    public const uint EVERYTHING3_PROPERTY_ID_SIZE = 2;
    public const uint EVERYTHING3_PROPERTY_ID_EXTENSION = 3;
    public const uint EVERYTHING3_PROPERTY_ID_TYPE = 4;
    public const uint EVERYTHING3_PROPERTY_ID_DATE_MODIFIED = 5;
    public const uint EVERYTHING3_PROPERTY_ID_DATE_CREATED = 6;
    public const uint EVERYTHING3_PROPERTY_ID_DATE_ACCESSED = 7;
    public const uint EVERYTHING3_PROPERTY_ID_ATTRIBUTES = 8;
    public const uint EVERYTHING3_PROPERTY_ID_FULL_PATH = 240;
}
"@

# Typ zu PowerShell hinzufügen
try {
    Add-Type -TypeDefinition $Everything3Type # -ErrorAction SilentlyContinue
    Write-Verbose "Everything3 SDK-Typen erfolgreich geladen"
}
catch {
    if ($_.Exception.Message -notmatch "already exists") {
        throw "Fehler beim Laden der Everything3 SDK-Typen: $($_.Exception.Message)"
    }
}

#endregion