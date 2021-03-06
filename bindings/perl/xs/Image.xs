MODULE = Media::Scan		PACKAGE = Media::Scan::Image

SV *
codec(MediaScanResult *r)
CODE:
{
  RETVAL = r->image->codec ? newSVpv(r->image->codec, 0) : &PL_sv_undef;
}
OUTPUT:
  RETVAL

int
width(MediaScanResult *r)
CODE:
{
  RETVAL = r->image->width;
}
OUTPUT:
  RETVAL
  
  
int
height(MediaScanResult *r)
CODE:
{
  RETVAL = r->image->height;
}
OUTPUT:
  RETVAL

