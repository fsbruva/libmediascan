///-------------------------------------------------------------------------------------------------
/// @file libmediascan\src\mediascan_win32.h
///
///  Win32 specific file system functionality
///-------------------------------------------------------------------------------------------------

#include "win32config.h"

#if defined(__MINGW32__) || defined(__MINGW64__)
#define INITGUID
#endif
#include <Windows.h>
#include <tchar.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <direct.h>
#include <tchar.h>
#include <Msi.h>
#include <Shobjidl.h>
#include <objbase.h>
#include <objidl.h>
#include <shlguid.h>
#include <shlobj.h>             /* For IShellLink */
#include <Shlwapi.h>
#include <initguid.h>

#include <libmediascan.h>


#include "common.h"
#include "queue.h"
#include "mediascan.h"
#include "progress.h"

#ifdef _MSC_VER
#pragma warning( disable: 4127 )
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "uuid.lib")
#pragma comment(lib, "Msi.lib")
#endif

///-------------------------------------------------------------------------------------------------
///  Win32 specific MediaScan initalization.
///
/// @author Henry Bennett
/// @date 03/15/2011
///-------------------------------------------------------------------------------------------------

void win32_init(void);

///-------------------------------------------------------------------------------------------------
///  Begin a recursive scan of all paths previously provided to ms_add_path(). If async mode
///   is enabled, this call will return immediately. You must obtain the file descriptor using
///   ms_async_fd and this must be checked using an event loop or select(). When the fd becomes
///   readable you must call ms_async_process to trigger any necessary callbacks.
///
/// @author Henry Bennett
/// @date 03/15/2011
///
/// @param [in,out] s If non-null, the.
///
/// ### remarks .
///-------------------------------------------------------------------------------------------------

void ms_scan(MediaScan *s);



///-------------------------------------------------------------------------------------------------
///  Code to refresh the directory listing, but not the subtree because it would not be necessary.
///
/// @author Henry Bennett
/// @date 03/22/2011
///
/// @param lpDir The pointer to a dir.
///-------------------------------------------------------------------------------------------------

void RefreshDirectory(MediaScan* s, LPTSTR lpDir);

int parse_lnk(LPCTSTR szShortcutFile, LPTSTR szTarget, SIZE_T cchTarget);
