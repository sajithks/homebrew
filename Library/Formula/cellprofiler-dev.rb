require 'formula'
require 'base64'

class DATADownloadStrategy < AbstractDownloadStrategy
  def initialize name, package
    super
    @temp_dest=HOMEBREW_CACHE+"#{name}-#{package.version}-setup.sh"
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
  depends_on 'swig'  # new requirement for scipy?

  # These are all modified to make sure they are universal.  In the
  # future, brew might allow us to have dependencies with options.
  depends_on 'libtiff-universal'
  depends_on 'mysql-connector-c'
  depends_on 'libhdf5-universal'
  depends_on 'zeromq-universal'
  depends_on 'freetype-universal'

  depends_on 'cellprofiler-dev-python'
  depends_on 'cellprofiler-dev-Pillow'

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
    system "touch", "#{prefix}/install.is.good"
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
# numpy/scipy/Cython

# For some reason, pip installs of nympy don't put everything in place
# that's needed, so we download and install it in the usual way.

echo $PATH
/usr/bin/curl -L -O https://github.com/numpy/numpy/archive/v1.7.0b2.zip
/usr/bin/unzip v1.7.0b2.zip
cd numpy-1.7.0b2
${VIRTUAL_ENV}/bin/python setup.py build --fcompiler=gnu95
${VIRTUAL_ENV}/bin/python setup.py install

cd ${VIRTUAL_ENV}/bin
./pip install scipy==0.11.0
./pip install Cython==0.15.1
./pip install nose==1.1.2
./pip install --install-option=--zmq=$(${HOMEBREW_BREW_FILE} --prefix zeromq-universal) pyzmq

# Create a nosetests that calls pythonw32
/bin/cp `which nosetests` ./nosetestsw32
/usr/bin/sed -i "" -e "s/python$/pythonw32/" nosetestsw32

# h5py
HDF5_DIR=`${HOMEBREW_BREW_FILE} --prefix libhdf5-universal` ./pip install h5py==2.0.1

./pip install git+git://github.com/matplotlib/matplotlib.git


# make sure we find mysql_config in the brew install
./pip install MySQL-python==1.2.3

# for py2app install
./pip install Mercurial
# install py2app & dependencies
./pip install hg+https://bitbucket.org/ronaldoussoren/altgraph@43294d014786
./pip install hg+https://bitbucket.org/ronaldoussoren/macholib@d65f105c8cd2
./pip install hg+https://bitbucket.org/ronaldoussoren/modulegraph@f9355a7edee0
./pip install hg+https://bitbucket.org/ronaldoussoren/py2app@0e3d19bbc464

# backup for writing TIFFs in CP.  Note that it includes its own copy of libtiff.
# ./pip install 'svn+http://pylibtiff.googlecode.com/svn/trunk'

# TODO: py2app fixups?  Still needed?
exit 0
