///-------------------------------------------------------------------------------------------------
/// @file libmediascan\src\win32_port.h
///
///  Win32 port class prototypes and defines
///-------------------------------------------------------------------------------------------------

#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <Windows.h>

#include "win32config.h"

int strcasecmp(const char* string1, const char* string2) {
	return _stricmp(string1, string2);
}

int strncasecmp(const char* s1, const char* s2, size_t n) {
	return _strnicmp(s1, s2, n);
}

///-------------------------------------------------------------------------------------------------
///  Gets a file size.
///
/// @author Henry Bennett
/// @date 04/09/2011
///
/// @param fileName            Filename of the file.
/// @param [in,out] lpszString File size converted to a string
/// @param dwSize              String length
///
/// @return success.
///-------------------------------------------------------------------------------------------------

int _GetFileSize(const char* fileName, char* lpszString, long dwSize);

///-------------------------------------------------------------------------------------------------
 ///  Gets a file's last modified time.
 ///
 /// @author Henry Bennett
 /// @date 04/09/2011
 ///
 /// @param fileName            Filename of the file.
 /// @param [in,out] lpszString Modified time formatted in a string
 /// @param dwSize              Length of a string
 ///
 /// @return success.
 ///-------------------------------------------------------------------------------------------------

int _GetFileTime(const char* fileName, char* lpszString, long dwSize);

 ///-------------------------------------------------------------------------------------------------
 ///  Touches a file, forcibly setting the last modified time to current system time.
 ///
 /// @author Henry Bennett
 /// @date 04/13/2011
 ///
 /// @param fileName            Filename of the file.
 ///
 /// @return integer return value from SetFileTime() function.
 ///-------------------------------------------------------------------------------------------------

int TouchFile(const char* fileName);

///-------------------------------------------------------------------------------------------------
///  Ends the program while outputting a final string to the console.
///
/// @author Henry Bennett
/// @date 03/15/2011
///
/// @param [in]  fmt parameter list like printf.
///
/// ### remarks .
///-------------------------------------------------------------------------------------------------

void croak(char* fmt, ...);
