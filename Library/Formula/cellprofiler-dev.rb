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

  # These are all modified to make sure they are universal.  In the
  # future, brew might allow us to have dependencies with options.
  depends_on 'libtiff-universal'
  depends_on 'mysql-connector-c-universal'
  depends_on 'libhdf5-universal'

  def older_version v1, v2
    v1 = v1.split('.').map{|s|s.to_i}.extend(Comparable)
    v2 = v2.split('.').map{|s|s.to_i}.extend(Comparable)
    return v1 < v2
  end

  def install
    # test that we're using a python installed in the expected place,
    # and that it's universal
    ohai "Checking that Python is in the right place and built for i386 and x86_64."
    python_executable='/Library/Frameworks/Python.framework/Versions/2.7/bin/python'
    if Dir[python_executable].empty?
      onoe "Did not find #{python_executable}."
      onoe "Please install python.org's build of python 2.7."
      exit 1
    end
    
    python_file_info=`/usr/bin/file #{python_executable}`
    if not (python_file_info.include? 'Mach-O executable i386' and
            python_file_info.include? 'Mach-O 64-bit executable x86_64')
      onoe "#{python_executable} does is not Universal i386 & x86_64."
      onoe "Please install python.org's build of python 2.7."
      exit 1
    end

    # test for virtualenv, and its version
    ohai "Checking that virtualenv is installed and a recent version."
    `/usr/bin/which virtualenv`
    if not $?.success?
      onoe 'Could not find virtualenv on the PATH.  Is it installed?'
      exit 1
    end

    virtualenv_version=`virtualenv --version`
    if not $?.success?
      onoe 'Failure running virtualenv --version (is it installed)'
      exit 1
    end

    if older_version virtualenv_version, "1.5.1"
      onoe 'This script has only been tested with virtualenv 1.5.1.  Please upgrade.'
      exit 1
    end

    # test for wxpython
    ohai "Checking that wxpython 2.8-unicode is installed."
    if Dir['/usr/local/lib/wxPython-unicode-2.8*/lib/python2.7'].empty?
      onoe "Didn't find anything matching ''/usr/local/lib/wxPython-unicode-2.8*/lib/python2.7'."
      onoe 'Please install wxpython 2.8 unicode for python 2.7 from wxpython.org'
      exit 1
    end

    # Begin installation
    ENV.universal_binary
    system "/bin/sh", "./setup.sh", "#{prefix}"
    (bin+"activate-cpdev").write <<-EOS.undent
    #!/bin/sh
    . #{prefix}/cpdev/bin/activate
    EOS
    test
  end

  def test
    ohai "Running tests"
    testfile = File.open('SmallTest.tif', 'w')
    testfile.write(Base64.decode64(File.open('setup.sh', 'r').read.split('MOREDATA')[1]))
    testfile.close()
    # run tests
    for arch in ["-x86_64", "-i386"]
      system "/usr/bin/arch", arch, "#{prefix}/cpdev/bin/python", "-c", "import scipy; print scipy.__version__"
      system "/usr/bin/arch", arch, "#{prefix}/cpdev/bin/python", "-c", "import MySQLdb; print MySQLdb.version_info"
      system "/usr/bin/arch", arch, "#{prefix}/cpdev/bin/python", "-c", "import h5py; print h5py.version.version_tuple"
      system "/usr/bin/arch", arch, "#{prefix}/cpdev/bin/python", "-c", "from PIL import Image; assert len(Image.open('SmallTest.tif').tostring()) == 10000"
    end
    system "#{prefix}/cpdev/bin/python32", "-c", "import matplotlib; print matplotlib.__version__"
  end
end


__END__
#!/bin/bash -v

# die on errors
set -e
set -o pipefail

# Clear a bunch of environment that Brew set up, but that break the scipy build
unset CFLAGS CXXFLAGS LDFLAGS

# useful below
export HBPREFIX=`${HOMEBREW_BREW_FILE} --prefix`

virtualenv -p /Library/Frameworks/Python.framework/Versions/2.7/bin/python --no-site-packages ${1}/cpdev

. ${1}/cpdev/bin/activate
cd ${1}/cpdev/bin

# Create a 32-bit python (we need it for installing matplotlib in 32-bit land)
/usr/bin/lipo ./python -thin i386 -output ./python32

# get a 32-bit framework build of python into the environment
/bin/cat > ./pythonw32 <<EOF
#!/bin/bash
PYTHONHOME=${VIRTUAL_ENV} /usr/bin/arch -arch i386 /Library/Frameworks/Python.framework/Versions/2.7/bin/pythonw "\$@"
EOF
/bin/chmod +x ./pythonw32

# Upgrade pip so it can fetch git+https URLs
./pip install -U pip 

# put in the wxredirect.pth
./python <<EOF
import os
import os.path
import glob
import sys
wxdirs = sorted(glob.glob('/usr/local/lib/wxPython-unicode-2.8*/lib/python2.7'))
assert len(wxdirs) > 0, "No directories matching %s found!" % ('/usr/local/lib/wxPython-unicode-2.8*/lib/python2.7')
dest = os.path.join(os.getenv('VIRTUAL_ENV'), 'lib', 'python2.7', 'site-packages', 'wxredirect.pth')
open(dest, 'w').write("import site; site.addsitedir('%s')\n" % (wxdirs[-1]))
sys.exit(0)
EOF

# Need to download PIL, patch its setup.py to find libjpeg and libtiff
# (the universal ones that Brew installed), then run setup.py
cd ${1}/cpdev
mkdir PIL_build
cd ${1}/cpdev/PIL_build
/usr/bin/curl http://dist.plone.org/thirdparty/PIL-1.1.7.tar.gz | tar -xzf -
cd PIL-1.1.7
/usr/bin/sed -i "" "s@^TIFF_ROOT = None@TIFF_ROOT=libinclude('${HBPREFIX}')@;s@^JPEG_ROOT = None@JPEG_ROOT=libinclude('${HBPREFIX}')@" setup.py
../../bin/python setup.py build_ext build install
# We won't bother cleaning up, for now, as having the PIL build directory around later may be useful.
cd ${1}/cpdev/bin

# numpy/scipy/Cython
./pip install numpy
./pip install scipy
./pip install Cython

# h5py
HDF5_DIR=`${HOMEBREW_BREW_FILE} --prefix libhdf5-universal` ./pip install h5py

# We need to use the 32 version of python we created above for matplotlib, as it uses wx.
# The last bit is a tag, not an actual .zip.  
PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/X11R6/lib/pkgconfig:${HBPREFIX}/lib/pkgconfig ./python32 ./pip install git+https://github.com/matplotlib/matplotlib.git@v1.0.1

# backup for writing TIFFs in CP.  Note that it includes its own copy of libtiff.
./pip install 'svn+http://pylibtiff.googlecode.com/svn/trunk'

# make sure we find mysql_config in the brew install
PATH=${HBPREFIX}/bin:$PATH ./pip install MySQL-python

# Note that we may have to patch py2app at some point:
# http://cellprofiler.org/wiki/index.php/Creating_a_standalone_.app_on_the_Mac#Building_with_setup.py_py2app
./pip install py2app==0.6.3

# TODO: py2app fixups?  Still needed?
exit 0

# Everything below is used for testing.
MOREDATA
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
PkHwJgUVICq2MubY7HEUwK/wk2IIPY6SPZCWjS8gwa3Q+Aq/GQwrGw6DG4PYYGPaIW54b6o2pil4
vTFqu+8XBoLolILcNA2I8gsE7bI8ykrqVgeCSoqSTIX4rlJY3W7i6o4glyLKJkp+q8ue2RFo/M2P
GSPIm2IGL8sSr5JDJdE7JzJ26g7PK9DBKe2TH7I+uO2un6n6v+6iN0/Q5em/KK7ghWxExSrwtzC8
tBJzGzJC9I73H1LI9lLzJAxQ8o+OtTLg+JC+1rKerNGRFBG0+nLdASyI6GsbAPBfLDL0vQ8WnBAR
IjMVL67cICAAEQEAAAMAAAABAGQAAAEBAAMAAAABAGQAAAECAAMAAAABAAgAAAEDAAMAAAABAAUA
AAEGAAMAAAABAAMAAAERAAQAAAABAAAACAESAAMAAAABAAEAAAEVAAMAAAABAAEAAAEWAAMAAAAB
AGQAAAEXAAQAAAABAAALlAEaAAUAAAABAAAMbgEbAAUAAAABAAAMdgEcAAMAAAABAAEAAAEoAAMA
AAABAAIAAAE9AAMAAAABAAIAAAFAAAMAAAMAAAAMfgFTAAMAAAABAAEAAAAAAABIAAAAAQAAAEgA
AAABAAAAAAABAQICAwMEBAUFBgYHBwgICQkKCgsLDAwNDQ4ODw8QEBEREhITExQUFRUWFhcXGBgZ
GRoaGxscHB0dHh4fHyAgISEiIiMjJCQlJSYmJycoKCkpKiorKywsLS0uLi8vMDAxMTIyMzM0NDU1
NjY3Nzg4OTk6Ojs7PDw9PT4+Pz9AQEFBQkJDQ0RERUVGRkdHSEhJSUpKS0tMTE1NTk5PT1BQUVFS
UlNTVFRVVVZWV1dYWFlZWlpbW1xcXV1eXl9fYGBhYWJiY2NkZGVlZmZnZ2hoaWlqamtrbGxtbW5u
b29wcHFxcnJzc3R0dXV2dnd3eHh5eXp6e3t8fH19fn5/f4CAgYGCgoODhISFhYaGh4eIiImJioqL
i4yMjY2Ojo+PkJCRkZKSk5OUlJWVlpaXl5iYmZmampubnJydnZ6en5+goKGhoqKjo6SkpaWmpqen
qKipqaqqq6usrK2trq6vr7CwsbGysrOztLS1tba2t7e4uLm5urq7u7y8vb2+vr+/wMDBwcLCw8PE
xMXFxsbHx8jIycnKysvLzMzNzc7Oz8/Q0NHR0tLT09TU1dXW1tfX2NjZ2dra29vc3N3d3t7f3+Dg
4eHi4uPj5OTl5ebm5+fo6Onp6urr6+zs7e3u7u/v8PDx8fLy8/P09PX19vb39/j4+fn6+vv7/Pz9
/f7+//8AAAEBAgIDAwQEBQUGBgcHCAgJCQoKCwsMDA0NDg4PDxAQERESEhMTFBQVFRYWFxcYGBkZ
GhobGxwcHR0eHh8fICAhISIiIyMkJCUlJiYnJygoKSkqKisrLCwtLS4uLy8wMDExMjIzMzQ0NTU2
Njc3ODg5OTo6Ozs8PD09Pj4/P0BAQUFCQkNDRERFRUZGR0dISElJSkpLS0xMTU1OTk9PUFBRUVJS
U1NUVFVVVlZXV1hYWVlaWltbXFxdXV5eX19gYGFhYmJjY2RkZWVmZmdnaGhpaWpqa2tsbG1tbm5v
b3BwcXFycnNzdHR1dXZ2d3d4eHl5enp7e3x8fX1+fn9/gICBgYKCg4OEhIWFhoaHh4iIiYmKiouL
jIyNjY6Oj4+QkJGRkpKTk5SUlZWWlpeXmJiZmZqam5ucnJ2dnp6fn6CgoaGioqOjpKSlpaamp6eo
qKmpqqqrq6ysra2urq+vsLCxsbKys7O0tLW1tra3t7i4ubm6uru7vLy9vb6+v7/AwMHBwsLDw8TE
xcXGxsfHyMjJycrKy8vMzM3Nzs7Pz9DQ0dHS0tPT1NTV1dbW19fY2NnZ2trb29zc3d3e3t/f4ODh
4eLi4+Pk5OXl5ubn5+jo6enq6uvr7Ozt7e7u7+/w8PHx8vLz8/T09fX29vf3+Pj5+fr6+/v8/P39
/v7//wAAAQECAgMDBAQFBQYGBwcICAkJCgoLCwwMDQ0ODg8PEBARERISExMUFBUVFhYXFxgYGRka
GhsbHBwdHR4eHx8gICEhIiIjIyQkJSUmJicnKCgpKSoqKyssLC0tLi4vLzAwMTEyMjMzNDQ1NTY2
Nzc4ODk5Ojo7Ozw8PT0+Pj8/QEBBQUJCQ0NEREVFRkZHR0hISUlKSktLTExNTU5OT09QUFFRUlJT
U1RUVVVWVldXWFhZWVpaW1tcXF1dXl5fX2BgYWFiYmNjZGRlZWZmZ2doaGlpampra2xsbW1ubm9v
cHBxcXJyc3N0dHV1dnZ3d3h4eXl6ent7fHx9fX5+f3+AgIGBgoKDg4SEhYWGhoeHiIiJiYqKi4uM
jI2Njo6Pj5CQkZGSkpOTlJSVlZaWl5eYmJmZmpqbm5ycnZ2enp+foKChoaKio6OkpKWlpqanp6io
qamqqqurrKytra6ur6+wsLGxsrKzs7S0tbW2tre3uLi5ubq6u7u8vL29vr6/v8DAwcHCwsPDxMTF
xcbGx8fIyMnJysrLy8zMzc3Ozs/P0NDR0dLS09PU1NXV1tbX19jY2dna2tvb3Nzd3d7e39/g4OHh
4uLj4+Tk5eXm5ufn6Ojp6erq6+vs7O3t7u7v7/Dw8fHy8vPz9PT19fb29/f4+Pn5+vr7+/z8/f3+
/v//
