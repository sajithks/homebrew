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

class CellprofilerDevPillow < Formula
  url "http://cellprofiler.org/wiki", :using => DATADownloadStrategy
  version '1'
  homepage 'http://cellprofiler.org/wiki/'
  md5 ''

  depends_on 'libjpeg'
  depends_on 'pkg-config' # missing on Snow Leopard?

  # These are all modified to make sure they are universal.  In the
  # future, brew might allow us to have dependencies with options.
  depends_on 'libtiff-universal'

  depends_on 'cellprofiler-dev-python'

  def install
    # Begin installation
    ENV.universal_binary
    system "touch", "#{prefix}/.good"
    system "/bin/sh", "./setup.sh", "#{prefix}"
    test
  end

  def test
    ohai "Running tests"
    testfile = File.open('SmallTest.tif', 'w')
    testfile.write(Base64.decode64(File.open('setup.sh', 'r').read.split('MOREDATA')[1]))
    testfile.close()
    # run tests
    python = "#{prefix}/../../cellprofiler-dev-python/1/cpdev/bin/python"
    if MacOS.snow_leopard?  # 10.6 or higher
      for arch in ["-x86_64", "-i386"]
        system "/usr/bin/arch", arch, python, "-c", "from PIL import Image; assert len(Image.open('SmallTest.tif').tostring()) == 10000"
      end
    else
      system python, "-c", "from PIL import Image; assert len(Image.open('SmallTest.tif').tostring()) == 10000"
    end
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

. ${HBPREFIX}/bin/activate-cpdev
cd ${VIRTUAL_ENV}/bin

./pip install -U 'git+https://github.com/thouis/Pillow.git'

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
