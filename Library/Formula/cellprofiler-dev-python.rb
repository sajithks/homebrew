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

class CellprofilerDevPython < Formula
  url "http://cellprofiler.org/wiki", :using => DATADownloadStrategy
  version '1'
  homepage 'http://cellprofiler.org/wiki/'
  md5 ''

  depends_on 'pkg-config' # missing on Snow Leopard?

  def older_version v1, v2
    v1 = v1.split('.').map{|s|s.to_i}.extend(Comparable)
    v2 = v2.split('.').map{|s|s.to_i}.extend(Comparable)
    return v1 < v2
  end

  def install
    # Make sure there are no spaces in the Homebrew path, or pip will fail.
    if HOMEBREW_PREFIX.to_s.include? ' '
      onoe "The homebrew directory \"#{HOMEBREW_PREFIX}\" contains spaces."
      onoe "Unfortunately, some python scripts (pip) cannot work in this case."
      exit 1
    end

    # test that we're using a python installed in the expected place,
    # and that it's universal if we're on 10.6 or higher
    ohai "Checking that Python is in the right place and built for i386 and x86_64."
    python_executable='/Library/Frameworks/Python.framework/Versions/2.7/bin/python'
    if Dir[python_executable].empty?
      onoe "Did not find #{python_executable}."
      onoe "Please install python.org's build of python 2.7."
      exit 1
    end
    
    if MacOS.snow_leopard?  # 10.6 or higher
      python_file_info=`/usr/bin/file #{python_executable}`
      if not (python_file_info.include? 'Mach-O executable i386' and
              python_file_info.include? 'Mach-O 64-bit executable x86_64')
        onoe "#{python_executable} does is not Universal i386 & x86_64."
        onoe "Please install python.org's build of python 2.7."
        exit 1
      end
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
      onoe 'Failure running virtualenv --version'
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

    # Use DYLD_FALLBACK_LIBRARY_PATH to insert things as late as possible in the search order.
    # Otherwise, gitk fails because they find a newer version of libjpeg than they expect.
    inreplace "#{prefix}/cpdev/bin/activate", "\nexport PATH\n", "\nexport PATH\nexport DYLD_FALLBACK_LIBRARY_PATH='#{HOMEBREW_PREFIX}'/lib:${DYLD_FALLBACK_LIBRARY_PATH}"
    (bin+"activate-cpdev").write <<-EOS.undent
    #!/bin/sh
    . "#{prefix}"/cpdev/bin/activate
    EOS
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

virtualenv -p /Library/Frameworks/Python.framework/Versions/2.7/bin/python --no-site-packages "${1}"/cpdev

. "${1}"/cpdev/bin/activate
cd "${1}"/cpdev/bin

# Create a 32-bit python (we need it for installing matplotlib in 32-bit land)
/usr/bin/lipo ./python -thin i386 -output ./python32

# get a 32-bit framework build of python into the environment
/bin/cat > ./pythonw32 <<EOF
#!/bin/bash
PYTHONHOME="${VIRTUAL_ENV}" /usr/bin/arch -arch i386 /Library/Frameworks/Python.framework/Versions/2.7/bin/pythonw "\$@"
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

exit 0
