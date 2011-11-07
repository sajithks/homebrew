require 'formula'

class CellprofilerDev < Formula
  url "https://raw.github.com/thouis/cpdev-setup-script/master/setup.sh"
  version '1'
  homepage 'http://cellprofiler.org/wiki/'
  md5 ''

  depends_on 'gfortran'
  # libjpeg is built universal 32/64 by brew
  depends_on 'libjpeg'

  # These are all modified to make sure they are universal.  In the
  # future, brew might allow us to have dependencies with options.
  depends_on 'libtiff-universal'
  depends_on 'mysql-connector-c-universal'
  depends_on 'libhdf5-universal'

  # todo: test python for 2.7, and universal

  if Dir['/usr/local/lib/wxPython-unicode-2.8*/lib/python2.7'].empty?
    onoe 'Please install wxpython 2.8 unicode for python 2.7 from wxpython.org'
    exit 1
  end

  def install

    ENV.universal_binary
    system "/bin/sh", "./setup.sh", "#{prefix}"
    (bin+"cpdev-activate").write <<-EOS.undent
    #!/bin/sh
    . #{prefix}/cpdev/bin/activate
    EOS
  end
end
__END__
