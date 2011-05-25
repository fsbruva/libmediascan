#include <stdio.h>
#include <string.h>


#ifdef WIN32
#include <Windows.h>
#include <direct.h>
#else
#include <fcntl.h>
#include <sys/wait.h>
#define _rmdir rmdir
#define _mkdir mkdir
#define CopyFile copyfile
#define DeleteFile deletefile
#endif

#include <limits.h>
#include <libmediascan.h>

#include "../src/mediascan.h"
#include "../src/database.h"
#include "Cunit/CUnit/Headers/Basic.h"

#ifndef MAX_PATH
#define MAX_PATH 1024
#endif

#ifndef WIN32

void Sleep(int ms)
{
	usleep(ms * 1000); // Convert to usec
} /* Sleep() */

int copyfile(char *source, char *dest, int not_used)
{
    int childExitStatus;
    pid_t pid;

    if (!source || !dest) {
        return FALSE;
    }

    pid = fork();

    if (pid == 0) { /* child */
        execl("/bin/cp", "/bin/cp", source, dest, (char *)0);
    }
    else if (pid < 0) {
        return FALSE;
    }
    else {
        /* parent - wait for child - this has all error handling, you
         * could just call wait() as long as you are only expecting to
         * have one child process at a time.
         */
        pid_t ws = waitpid( pid, &childExitStatus, WNOHANG);
        if (ws == -1)
        { 
        return FALSE;
        }

        if( WIFEXITED(childExitStatus)) /* exit code in childExitStatus */
        {
            int status = WEXITSTATUS(childExitStatus); /* zero is normal exit */
            /* handle non-zero as you wish */
        }
    }
    return TRUE;
} /* copyfile() */

int deletefile(char *source)
{
    int childExitStatus;
    pid_t pid;

    if (!source) {
        return FALSE;
    }

    pid = fork();

    if (pid == 0) { /* child */
        execl("/bin/rm", "/bin/rm", source, (char *)0);
    }
    else if (pid < 0) {
        return FALSE;
    }
    else {
        /* parent - wait for child - this has all error handling, you
         * could just call wait() as long as you are only expecting to
         * have one child process at a time.
         */
        pid_t ws = waitpid( pid, &childExitStatus, WNOHANG);
        if (ws == -1)
        { 
        return FALSE;
        }

        if( WIFEXITED(childExitStatus)) /* exit code in childExitStatus */
        {
            int status = WEXITSTATUS(childExitStatus); /* zero is normal exit */
            /* handle non-zero as you wish */
        }
    }
    return TRUE;
} /* deletefile() */

#endif

static int result_called = 0;
static MediaScanResult result;

static void my_result_callback(MediaScan *s, MediaScanResult *r, void *userdata) {

	result.type = r->type;
	result.path = strdup(r->path);
	result.flags = r->flags;

	if(r->error)
		memcpy(result.error, r->error, sizeof(MediaScanError));

	result.mime_type = strdup(r->mime_type);
	result.dlna_profile = strdup(r->dlna_profile);
	result.size = r->size;
	result.mtime = r->mtime;
	result.bitrate = r->bitrate;
	result.duration_ms = r->duration_ms;

	if(r->audio)
	{
		result.audio = malloc(sizeof(MediaScanAudio));
		memcpy( result.audio, r->audio, sizeof(MediaScanAudio));
	}

	if(r->video)
	{
		result.video = malloc(sizeof(MediaScanVideo));
		memcpy( result.video, r->video, sizeof(MediaScanVideo));
	}

	if(r->image)
	{
		result.image = malloc(sizeof(MediaScanImage));
		memcpy( result.image, r->image, sizeof(MediaScanImage));
	}

	result_called++;
} /* my_result_callback() */

static void my_error_callback(MediaScan *s, MediaScanError *error, void *userdata) { 

} /* my_error_callback() */

///-------------------------------------------------------------------------------------------------
///  Test background api
///
/// @author Henry Bennett
/// @date 03/18/2011
///-------------------------------------------------------------------------------------------------
#define MAKE_PATH(str, path, file)  	{ strcpy((str), (path)); strcat((str), "\\"); strcat((str), (file)); }

static void PathCopyFile(const char *file, const char *src_path, const char *dest_path) 
{
	char src[MAX_PATH];
	char dest[MAX_PATH];

	MAKE_PATH(src, src_path, file);
	MAKE_PATH(dest, dest_path, file);

	printf("Copying %s to %s\n", src, dest);
	CopyFile(src, dest, FALSE);
}

static void test_background_api(void)	{
	const char *test_path = "C:\\Siojej3";
	const char *data_path = "data\\video";
	const char *data_file1 = "bars-mpeg1video-mp2.mpg";
	const char *data_file2 = "bars-msmpeg4-mp2.asf";
	const char *data_file3 = "bars-msmpeg4v2-mp2.avi";
	const char *data_file4 = "bars-vp8-vorbis.webm";
	const char *data_file5 = "wmv92-with-audio.wmv";
//	char src[MAX_PATH];
	char dest[MAX_PATH];

	MediaScan *s = ms_create();

	CU_ASSERT_FATAL(s != NULL);

	// Do some setup for the test
	CU_ASSERT( _mkdir(test_path) != -1 );
	result_called = 0;
	
	CU_ASSERT(s->on_result == NULL);
	ms_set_result_callback(s, my_result_callback);
	CU_ASSERT(s->on_result == my_result_callback);

	CU_ASSERT(s->on_error == NULL);
	ms_set_error_callback(s, my_error_callback); 
	CU_ASSERT(s->on_error == my_error_callback);

	ms_watch_directory(s, test_path);
	CU_ASSERT( result_called == 0 );
	Sleep(1000); // Sleep 1 second
	CU_ASSERT( result_called == 0 );
	
	// Now copy a small video file to the test directory
	PathCopyFile(data_file1, data_path, test_path );

	CU_ASSERT( result_called == 0 );
	Sleep(1000); // Sleep 1 second

	// Now process the callbacks
	ms_async_process(s);
	CU_ASSERT( result_called == 1 );
	
	result_called = 0;

	PathCopyFile(data_file2, data_path, test_path );
	Sleep(2000); // Sleep 1 second

	// Now process the callbacks
	ms_async_process(s);
	CU_ASSERT( result_called == 1 );
	
	reset_bdb(s);
	result_called = 0;

	MAKE_PATH(dest, test_path, data_file1);
	printf("Deleting %s\n", dest);
	CU_ASSERT( DeleteFile(dest) == TRUE);
	Sleep(1500); // Sleep 500 milliseconds
	MAKE_PATH(dest, test_path, data_file2);
	printf("Deleting %s\n", dest);
	CU_ASSERT( DeleteFile(dest) == TRUE);
	Sleep(1500); // Sleep 500 milliseconds

	PathCopyFile(data_file1, data_path, test_path );
	Sleep(500); // Sleep 500 milliseconds
	PathCopyFile(data_file2, data_path, test_path );
	Sleep(1500); // Sleep 500 milliseconds
	PathCopyFile(data_file3, data_path, test_path );
	Sleep(500); // Sleep 500 milliseconds
	PathCopyFile(data_file4, data_path, test_path );
	Sleep(100); // Sleep 500 milliseconds
	PathCopyFile(data_file5, data_path, test_path );
	Sleep(500); // Sleep 500 milliseconds

	// Now process the callbacks
	ms_async_process(s);
	CU_ASSERT( result_called == 5 );

	ms_destroy(s);

	// Clean up the test
	MAKE_PATH(dest, test_path, data_file1);
	DeleteFile(dest);
	MAKE_PATH(dest, test_path, data_file2);
	DeleteFile(dest);
	MAKE_PATH(dest, test_path, data_file3);
	DeleteFile(dest);
	MAKE_PATH(dest, test_path, data_file4);
	DeleteFile(dest);
	MAKE_PATH(dest, test_path, data_file5);
	DeleteFile(dest);

	CU_ASSERT( _rmdir(test_path) != -1 );

} /* test_background_api() */

static void test_background_api2(void)	{
	const char *test_path = "C:\\4oij3";
	const char *data_path = "data\\video";
	const char *data_file1 = "bars-mpeg1video-mp2.mpg";
	const char *data_file2 = "bars-msmpeg4-mp2.asf";
	const char *data_file3 = "bars-msmpeg4v2-mp2.avi";
	const char *data_file4 = "bars-vp8-vorbis.webm";
	const char *data_file5 = "wmv92-with-audio.wmv";
//	char src[MAX_PATH];
	char dest[MAX_PATH];

	MediaScan *s = ms_create();

	CU_ASSERT_FATAL(s != NULL);

	// Do some setup for the test
	CU_ASSERT( _mkdir(test_path) != -1 );
	result_called = 0;
	
	CU_ASSERT(s->on_result == NULL);
	ms_set_result_callback(s, my_result_callback);
	CU_ASSERT(s->on_result == my_result_callback);

	CU_ASSERT(s->on_error == NULL);
	ms_set_error_callback(s, my_error_callback); 
	CU_ASSERT(s->on_error == my_error_callback);

	ms_watch_directory(s, test_path);
	Sleep(1000); // Sleep 1 second

	// Now copy a small video file to the test directory
	PathCopyFile(data_file1, data_path, test_path );
	CU_ASSERT( result_called == 0 );


	// Now process the callbacks
	ms_async_process(s);
	CU_ASSERT( result_called == 1 );

	MAKE_PATH(dest, test_path, data_file1);
	CU_ASSERT( DeleteFile(dest) == TRUE);


	ms_destroy(s);

	// Clean up the test
	CU_ASSERT( _rmdir(test_path) != -1 );

} /* test_background_api2() */


static void test_background_api3(void)	{
	const char *test_path = "\\\\magento\\share";
	const char *test_path2 = "C:\\4o34ij3";
	const char *test_path3 = "Z:\\";
	const char *test_path4 = "C:\\data";

	MediaScan *s = ms_create();

	CU_ASSERT_FATAL(s != NULL);

	// Do some setup for the test
	result_called = 0;
	ms_errno = 0;
	CU_ASSERT( _mkdir(test_path2) != -1 );

	CU_ASSERT(s->on_result == NULL);
	ms_set_result_callback(s, my_result_callback);
	CU_ASSERT(s->on_result == my_result_callback);

	CU_ASSERT(s->on_error == NULL);
	ms_set_error_callback(s, my_error_callback); 
	CU_ASSERT(s->on_error == my_error_callback);

	ms_watch_directory(s, test_path);
	CU_ASSERT(ms_errno == MSENO_ILLEGALPARAMETER); // If we got this errno, then we got the failure we wanted

	// Test a directory that looks like a mapped network drive but isn't
	ms_errno = 0;
	ms_watch_directory(s, test_path2);
	CU_ASSERT(ms_errno == 0); 

	// Now test a mapped network drive
	ms_errno = 0;
	ms_watch_directory(s, test_path3);
	CU_ASSERT(ms_errno == MSENO_ILLEGALPARAMETER); 

	// Now test a NTFS mounted folder
//	ms_errno = 0;
//	ms_watch_directory(s, test_path4);
//	CU_ASSERT(ms_errno == 0); 


	ms_destroy(s);

	// Clean up the test
	CU_ASSERT( _rmdir(test_path2) != -1 );
} /* test_background_api3() */

static void test_win32_shortcuts(void)	{
	const char *test_path = "data\\video\\shortcuts";

	MediaScan *s = ms_create();

	CU_ASSERT_FATAL(s != NULL);

	// Do some setup for the test
	result_called = 0;
	ms_errno = 0;

	CU_ASSERT(s->on_result == NULL);
	ms_set_result_callback(s, my_result_callback);
	CU_ASSERT(s->on_result == my_result_callback);

	CU_ASSERT(s->on_error == NULL);
	ms_set_error_callback(s, my_error_callback); 
	CU_ASSERT(s->on_error == my_error_callback);

	CU_ASSERT(s->npaths == 0);
	ms_add_path(s, test_path);
	CU_ASSERT(s->npaths == 1);

	ms_scan(s);
	CU_ASSERT( result_called == 1 );

	ms_destroy(s);

} /* test_win32_shortcuts() */


static void test_async_api(void)	{

  long time1, time2;

	#ifdef WIN32
	const char dir[MAX_PATH] = "data\\video\\dlna";
	#else
	const char dir[MAX_PATH] = "data/video/dlna";
  struct timeval now;
	#endif

	MediaScan *s = ms_create();

	CU_ASSERT(s->npaths == 0);
	ms_add_path(s, dir);
	CU_ASSERT(s->npaths == 1);

	CU_ASSERT( s->async == FALSE );
	ms_set_async(s, FALSE);
	CU_ASSERT( s->async == FALSE );

	CU_ASSERT(s->on_result == NULL);
	ms_set_result_callback(s, my_result_callback);
	CU_ASSERT(s->on_result == my_result_callback);

	CU_ASSERT(s->on_error == NULL);
	ms_set_error_callback(s, my_error_callback); 
	CU_ASSERT(s->on_error == my_error_callback);

	ms_scan(s);
	CU_ASSERT( result_called == 5 );

	result_called = 0;
	reset_bdb(s);


	CU_ASSERT( s->async == FALSE );
	ms_set_async(s, TRUE);
	CU_ASSERT( s->async == TRUE );

#ifdef WIN32
  time1 = GetTickCount();
#else
  gettimeofday(&now, NULL);
  time1 = then.tv_sec;
#endif

	ms_scan(s);
	CU_ASSERT( result_called == 0 );

#ifdef WIN32
  time2 = GetTickCount();
#else
  gettimeofday(&now, NULL);
  time2 = then.tv_sec;
#endif

	// Verify that the function returns almost immediately
	CU_ASSERT( time2 - time1 < 20 );

	Sleep(1000); // Sleep 1 second

	// Now process the callbacks
	ms_async_process(s);
	CU_ASSERT( result_called == 5 );

	ms_destroy(s);
} /* test_async_api() */

///-------------------------------------------------------------------------------------------------
///  Setup background tests.
///
/// @author Henry Bennett
/// @date 03/22/2011
///-------------------------------------------------------------------------------------------------

int setupbackground_tests() {
	CU_pSuite pSuite = NULL;


   /* add a suite to the registry */
   pSuite = CU_add_suite("Background Scanning", NULL, NULL);
   if (NULL == pSuite) {
      CU_cleanup_registry();
      return CU_get_error();
   }

   /* add the tests to the background scanning suite */
   if (
//   NULL == CU_add_test(pSuite, "Test background scanning API", test_background_api) 
//   NULL == CU_add_test(pSuite, "Test background scanning Deletion", test_background_api2) //||
//	   NULL == CU_add_test(pSuite, "Test Async scanning API", test_async_api)
//   NULL == CU_add_test(pSuite, "Test edge cases of background scanning API", test_background_api3) 
   NULL == CU_add_test(pSuite, "Test Win32 shortcuts", test_win32_shortcuts) 

   
	   )
   {
      CU_cleanup_registry();
      return CU_get_error();
   }

   return 0;

} /* setupbackground_tests() */