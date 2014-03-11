class Ruby193 < FPM::Cookery::Recipe

  $rubyversion = '2.0.0-p451'
  rubyinstallversion = '0.4.1'
  rubyinstallsha256  = '1b35d2b6dbc1e75f03fff4e8521cab72a51ad67e32afd135ddc4532f443b730e'
  
  # Rewrite ruby version string to be packaging-friendly
  v = $rubyversion.sub(/-p/,'.')

  # Package metadata
  description 'The Ruby virtual machine'
  name 'ruby'
  version "#{v}"
  revision 1
  homepage 'http://www.ruby-lang.org/'
  maintainer 'code@beddari.net'
  license    'The Ruby License'
  section 'interpreters'

  # Source and sha for ruby-install
  source "https://github.com/postmodern/ruby-install/archive/v#{rubyinstallversion}.tar.gz"
  sha256 "#{rubyinstallsha256}"

  def build
    # Install ruby-install
    make :install
  end

  def install
    # Download, cache and build
    safesystem "/usr/local/bin/ruby-install -i #{destdir} -s #{cachedir} \
      ruby #{$rubyversion} -- --disable-install-doc --enable-shared"
    # Shrink
    rm_f "#{destdir}/lib/libruby-static.a"
    safesystem "strip #{destdir}/bin/ruby"
    safesystem "find #{destdir} -name '*.so' -or -name '*.so.*' | xargs strip"
  end
end

