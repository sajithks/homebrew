require 'formula'

class Libhdf5Universal < Formula
  url "http://dl.dropbox.com/u/16028921/HDF5-Universal.tar.bz2"
  version '1'
  homepage 'http://cellprofiler.org/wiki/'
  md5 '52e942bbf676267a90dd6daec35c9ced'

  keg_only "HDF5 doesn't build in universal mode, so we use a hand-built binary."

  def install
    # XXX - need to move this to cp.org/linked_files and make it better organized.
    puts Dir['local/HDF5-universal/*']
    prefix.install Dir['local/HDF5-universal/*']
  end
end
