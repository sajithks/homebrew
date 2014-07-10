require 'formula'
require 'base64'

class DATADownloadStrategy < AbstractDownloadStrategy
  def initialize url, name, version, specs
    super
    @temp_dest=HOMEBREW_CACHE+"#{name}-#{version}-setup.sh"
  end

  def fetch
    File.open("#{@temp_dest}", 'w') {|f| f.write(DATA.read) }
  end

  def stage
    FileUtils.mv @temp_dest, "setup.sh"
  end
end

class CellprofilerDev < Formula
  url "http://cellprofiler.org/wiki", :using => DATADownloadStrategy
  version '1'
  homepage 'http://cellprofiler.org/wiki/'
  md5 ''

  depends_on 'gfortran'
  # libjpeg is built universal 32/64 by brew
  depends_on 'libjpeg'
  depends_on 'pkg-config' # missing on Snow Leopard?

  # These are all modified to make sure they are universal.  In the
  # future, brew might allow us to have dependencies with options.
  depends_on 'libtiff-universal'
  depends_on 'mysql-connector-c'
  depends_on 'libhdf5-universal'
  #depends_on 'zeromq-universal'
  #depends_on 'zeromq'
  depends_on 'libpng'
  depends_on 'freetype'

  depends_on 'cellprofiler-dev-python'

  def older_version v1, v2
    v1 = v1.split('.').map{|s|s.to_i}.extend(Comparable)
    v2 = v2.split('.').map{|s|s.to_i}.extend(Comparable)
    return v1 < v2
  end

  def install
    # Begin installation
    ENV.fortran
    if MacOS.snow_leopard?
      ENV.universal_binary
    end
    system "touch", "#{prefix}/.good"
    system "/bin/sh", "./setup.sh", "#{prefix}"
    test
  end

  def test
    ohai "Running tests"
    # run tests
    python = "#{prefix}/../../cellprofiler-dev-python/1/cpdev/bin/python"
    if MacOS.snow_leopard?
      arches = ["-x86_64", "-i386"]
    else
      arches = ["-i386"]
    end
    for arch in arches
      system "/usr/bin/arch", arch, python, "-c", "import scipy; print scipy.__version__"
      system "/usr/bin/arch", arch, python, "-c", "import MySQLdb; print MySQLdb.version_info"
      system "/usr/bin/arch", arch, python, "-c", "import h5py; print h5py.version.version_tuple"
      system "/usr/bin/arch", arch, python, "-c", "import matplotlib; print matplotlib.__version__"
    end
  end
end

__END__
#!/bin/bash -v

# die on errors
set -e
set -o pipefail

# Clear a bunch of environment that Brew set up, but that break the scipy build
unset CFLAGS CXXFLAGS LDFLAGS F77 FC FCFLAGS FFLAGS

# useful below
export HBPREFIX=`${HOMEBREW_BREW_FILE} --prefix`

. ${HBPREFIX}/bin/activate-cpdev
cd ${VIRTUAL_ENV}/bin

# numpy/scipy/Cython
#
# Use forked Numpy 1.8.x maintenance branch. patched to fix
# Numpy issue numpy/numpy#4583
#
NUMPY_DIR=${HBPREFIX}/Cellar/numpy
rm -rf $NUMPY_DIR
mkdir $NUMPY_DIR
curl -L https://github.com/CellProfiler/numpy/archive/maintenance/1.8.x.tar.gz | tar zx -C $NUMPY_DIR --strip-components=1
cd $NUMPY_DIR
python setup.py build install
cd ${VIRTUAL_ENV}/bin
./pip install scipy==0.13.2
./pip install Cython==0.15.1
./pip install nose==1.1.2
./pip install pyzmq==2.2.0.1 --install-option=--zmq=bundled
./pip install pytz

# Create a nosetests that calls pythonw32
/bin/cp `which nosetests` ./nosetestsw32
/usr/bin/sed -i "" -e "s/python$/pythonw32/" nosetestsw32

${HOMEBREW_BREW_FILE} link libhdf5-universal
# h5py
# The h5py project has started hosting the files external to pypi, so
# additional options are needed to tell pip that it's ok to install it.
HDF5_DIR=`${HOMEBREW_BREW_FILE} --prefix libhdf5-universal` ./pip install h5py==2.1.3 --allow-all-external --allow-unverified h5py

PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/X11R6/lib/pkgconfig:${HBPREFIX}/lib/pkgconfig ./python32 ./pip install matplotlib==1.1.1

# make sure we find mysql_config in the brew install
# When building on 10.9, -mmacosx-version-min=10.6 works for both
# architectures whereas CFLAGS="-stdlib=libstdc++" does not.
ARCH_FLAGS="-arch i386 -arch x86_64 -mmacosx-version-min=10.6" ./pip install MySQL-python==1.2.5

./pip install Pillow==2.3.0

# for py2app install
./pip install Mercurial==2.8.2
# install py2app & dependencies
./pip install macholib==1.5.1
./pip install py2app==0.7.3

# backup for writing TIFFs in CP.  Note that it includes its own copy of libtiff.
./pip install 'svn+http://pylibtiff.googlecode.com/svn/trunk'
# pylibtiff creates a python module to bind to libtiff when
# it first imports. So we have to do that here. (CP build machine
# creates the brew in one account, then accesses it in an account
# that does not have permission to do this).
python -c "import libtiff"
# TODO: py2app fixups?  Still needed?
exit 0
