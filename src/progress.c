///-------------------------------------------------------------------------------------------------
// file:	libmediascan\src\progress.c
//
// summary:	MediaScanProgress class
///-------------------------------------------------------------------------------------------------

#ifdef WIN32
#include "win32/include/win32config.h"
#else
#include <sys/time.h>
#include <unistd.h>
#endif

#include <stdarg.h>
#include <stdlib.h>


#include <libmediascan.h>
#include "common.h"

///-------------------------------------------------------------------------------------------------
///  Create a new MediaScanProgress instance.
///
/// @author Henry Bennett
/// @date 03/15/2011
///
/// @return null if it fails, else.
///
/// ### remarks .
///-------------------------------------------------------------------------------------------------

MediaScanProgress *progress_create(void)
{
  MediaScanProgress *p = (MediaScanProgress *)calloc(sizeof(MediaScanProgress), 1);
  if (p == NULL) {
	ms_errno = MSENO_MEMERROR;
    FATAL("Out of memory for new MediaScanProgress object\n");
    return NULL;
  }
  
  p->interval = 1;
  p->rate = -1;
  p->eta = -1;
  
  LOG_MEM("new MediaScanProgress @ %p\n", p);
  
  return p;
} /* progress_create() */

void
progress_start_phase(MediaScanProgress *p, const char *fmt, ...)
{
  char *phase = (char *)malloc((size_t)MAX_PATH);
  struct timeval now;
  va_list ap;
  
  if (p->phase)
    free(p->phase);
  
  va_start(ap, fmt);  
  vsprintf(phase, fmt, ap);
  va_end(ap);
  
  p->phase = phase;
  
#ifdef WIN32
  p->_start_ts = GetTickCount();
#else
  gettimeofday(&now, NULL);
  p->_start_ts = now.tv_sec;
#endif
} /* progress_start_phase() */

// Returns 1 if progress was updated and callback should be called
int
progress_update(MediaScanProgress *p, const char *cur_item)
{
  long time;
  
#ifdef WIN32
  time = GetTickCount();
#else
  struct timeval now;

  gettimeofday(&now, NULL);
  time = now.tv_sec;
#endif

  LOG_DEBUG("progress_update %s\n", cur_item);


  if (time - p->_last_update_ts >= p->interval) {
    int elapsed = time - p->_start_ts;
    
    if (elapsed > 0) {
      p->rate = (int)((p->done / elapsed) + 0.5);
      if (p->total && p->rate > 0)
        p->eta = (int)(((p->total - p->done) / p->rate) + 0.5);
    }
    
    p->cur_item = cur_item;
    p->_last_update_ts = time;
    
    return 1;
  }
  
  return 0;
} /* progress_update() */

///-------------------------------------------------------------------------------------------------
///  Destroy a MediaScanProgress instance.
///
/// @author Henry Bennett
/// @date 03/15/2011
///
/// @param [in,out] p If non-null, the.
///
/// ### remarks .
///-------------------------------------------------------------------------------------------------

void progress_destroy(MediaScanProgress *p)
{
  if (p->phase)
    free(p->phase);
  
  LOG_MEM("destroy MediaScanProgress @ %p\n", p);  
  free(p);
} /* progress_destroy() */
