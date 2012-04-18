require 'formula'

class LibtiffUniversal < Formula
  homepage 'http://www.remotesensing.org/libtiff/'
  url 'http://download.osgeo.org/libtiff/tiff-4.0.0beta7.tar.gz'
  sha256 '7b622db9e62a14464b0ae27e5eed4e2e893d7aab889c778e56ac28df069c3ded'

  def install
    ENV.universal_binary
    ENV.osx_10_5
    # could not get opengl to work, and easiest way to turn it off seems to be to disable X
    system "./configure", "--prefix=#{prefix}", "--mandir=#{man}", "--disable-dependency-tracking", "--disable-cxx", "--with-x=no"
    # I don't want to fight with autconf, especially since libtiff
    # requires an autoconf version greater than the default on OSX 10.6
    inreplace 'libtiff/tiffconf.h', '#endif /* _TIFFCONF_ */', DATA.read + '#endif /* _TIFFCONF_ */'
    File.open("libtiff/tif_config.h", File::WRONLY|File::APPEND) {|f| f.write(DATA.read) }
    system "make install"
  end
end

__END__
#ifdef HAVE_STDINT_H
#undef TIFF_INT16_T
#undef TIFF_INT32_T
#undef TIFF_INT64_T
#undef TIFF_INT8_T
#undef TIFF_PTRDIFF_T
#undef TIFF_SSIZE_T
#undef TIFF_UINT16_T
#undef TIFF_UINT32_T
#undef TIFF_UINT64_T
#undef TIFF_UINT8_T

#include <stdint.h>
#define TIFF_INT8_T int8_t
#define TIFF_INT16_T int16_t
#define TIFF_INT32_T int32_t
#define TIFF_INT64_T int64_t
#define TIFF_UINT8_T uint8_t
#define TIFF_UINT16_T uint16_t
#define TIFF_UINT32_T uint32_t
#define TIFF_UINT64_T uint64_t
#define TIFF_PTRDIFF_T intptr_t
#define TIFF_SSIZE_T intptr_t
#endif

