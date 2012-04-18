require 'formula'

class Distribute < Formula
  url 'http://pypi.python.org/packages/source/d/distribute/distribute-0.6.24.tar.gz'
  md5 '17722b22141aba8235787f79800cc452'
end

class Python105sdk < Formula
  homepage 'http://www.python.org/'
  url 'http://www.python.org/ftp/python/2.7.2/Python-2.7.2.tar.bz2'
  md5 'ba7b2f11ffdbf195ee0d111b9455a5bd'

  depends_on 'readline' => :optional # Prefer over OS X's libedit
  depends_on 'sqlite'   => :optional # Prefer over OS X's older version
  depends_on 'gdbm'     => :optional

  keg_only :provided_by_osx, "This is for CellProfiler building, only."

  def patches
    # Turn of tkinter to avoid 10.5 build issues.
    # Fix for recognizing gdbm 1.9.x databases; already upstream:
    # http://hg.python.org/cpython/rev/14cafb8d1480
    DATA
  end

  # Skip binaries so modules will load; skip lib because it is mostly Python files
  skip_clean ['bin', 'lib']

  def install
    # Python requires -fwrapv for proper Decimal division with Clang. See:
    # https://github.com/mxcl/homebrew/pull/10487
    # http://stackoverflow.com/questions/7590137/dividing-decimals-yields-invalid-results-in-python-2-5-to-2-7
    # https://trac.macports.org/changeset/87442
    ENV.append_to_cflags "-fwrapv"
    ENV.append_to_cflags "-I#{HOMEBREW_PREFIX}/include"
    ENV.append_to_cflags "-mmacosx-version-min=10.5"
    ENV.append 'LDFLAGS', "-mmacosx-version-min=10.5"
    args = ["--prefix=#{prefix}"]
    args << "--enable-universalsdk=/Developer/SDKs/MacOSX10.5.sdk/" << "--with-universal-archs=intel"
    args << "--enable-framework=#{prefix}/Library/Frameworks"

    # allow sqlite3 module to load extensions
    inreplace "setup.py",
      'sqlite_defines.append(("SQLITE_OMIT_LOAD_EXTENSION", "1"))', ''

    system "./configure", *args

    # HAVE_POLL is "broken" on OS X
    # See: http://trac.macports.org/ticket/18376
    inreplace 'pyconfig.h', /.*?(HAVE_POLL[_A-Z]*).*/, '#undef \1'

    system "make"
    ENV.j1 # Installs must be serialized
    system "make install"

    # Install distribute. The user can then do:
    # $ easy_install pip
    # $ pip install --upgrade distribute
    # to get newer versions of distribute outside of Homebrew.
    Distribute.new.brew { system "#{bin}/python", "setup.py", "install" }

    # install pip, use it to install virtualenv, and upgrade distribute
    frameworkbin = "#{prefix}/Library/Frameworks/Python.framework/Versions/2.7/bin"
    system "#{frameworkbin}/easy_install pip"
    system "#{frameworkbin}/pip install -U virtualenv"
    system "#{frameworkbin}/pip install -U distribute"
  end

  def caveats
    general_caveats = <<-EOS.undent
      See: https://github.com/mxcl/homebrew/wiki/Homebrew-and-Python
    EOS

    s = general_caveats
    return s
  end

  def test
    # See: https://github.com/mxcl/homebrew/pull/10487
    system "#{bin}/python -c 'from decimal import Decimal; print Decimal(4) / Decimal(2)'"
  end
end

__END__
diff --git a/setup.py b/setup.py
--- a/setup.py
+++ b/setup.py
index 09534d2..2ea52f9 100644
@@ -1605,7 +1605,7 @@ class PyBuildExt(build_ext):
         self.extensions.extend(exts)
 
         # Call the method for detecting whether _tkinter can be compiled
-        self.detect_tkinter(inc_dirs, lib_dirs)
+        # self.detect_tkinter(inc_dirs, lib_dirs)
 
         if '_tkinter' not in [e.name for e in self.extensions]:
             missing.append('_tkinter')
diff --git a/Lib/whichdb.py b/Lib/whichdb.py
index 09534d2..2ea52f9 100644
--- a/Lib/whichdb.py
+++ b/Lib/whichdb.py
@@ -91,7 +91,7 @@ def whichdb(filename):
         return ""
 
     # Check for GNU dbm
-    if magic == 0x13579ace:
+    if magic in (0x13579ace, 0x13579acd, 0x13579acf):
         return "gdbm"

