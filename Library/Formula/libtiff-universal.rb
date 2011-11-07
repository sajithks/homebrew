require 'formula'

class LibtiffUniversal < Formula
  homepage 'http://www.remotesensing.org/libtiff/'
  url 'http://download.osgeo.org/libtiff/tiff-4.0.0beta7.tar.gz'
  sha256 '7b622db9e62a14464b0ae27e5eed4e2e893d7aab889c778e56ac28df069c3ded'

  def install
    ENV.universal_binary
    # could not get opengl to work, and easiest way to turn it off seems to be to disable X
    system "./configure", "--prefix=#{prefix}", "--mandir=#{man}", "--disable-dependency-tracking", "--disable-cxx", "--with-x=no"
    system "make install"
  end
end
