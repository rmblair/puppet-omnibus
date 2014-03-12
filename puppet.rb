class PuppetGem < FPM::Cookery::Recipe
  description 'Puppet gem stack'

  name 'puppet'
  version '3.4.3'

  source "https://github.com/puppetlabs/puppet/archive/#{version}.tar.gz"
  sha256 '9171082d6acda671e664182fa0cd1761b0c8fab195ed6c0ace2c953e6282d910'

  platforms [:ubuntu, :debian] do
    build_depends 'libaugeas-dev', 'pkg-config'
    depends 'libaugeas0', 'pkg-config'
  end

  platforms [:fedora, :redhat, :centos] do
    build_depends 'augeas-devel', 'pkgconfig'
    depends 'augeas-libs', 'pkgconfig'
  end

  def build
    # We need bundler in the omnibus ruby to handle the gems
    gem_install 'bundler', '1.5.3'

    # Cache the main Puppet bundle to disk
    bundle_prepare "#{name}-#{version}-Gemfile", "#{name}-#{version}-Gemfile.lock"

    build_files
  end

  def install

    bundle_install "#{name}-#{version}-Gemfile"

    # Install init-script and puppet.conf
    install_files

    # Provide 'safe' binaries in /opt/<package>/bin like Vagrant does
    rm_rf "#{destdir}/../bin"
    destdir('../bin').mkdir
    destdir('../bin').install workdir('omnibus.bin'), 'puppet'
    destdir('../bin').install workdir('omnibus.bin'), 'facter'
    destdir('../bin').install workdir('omnibus.bin'), 'hiera'

    # Symlink binaries to PATH using update-alternatives
    with_trueprefix do
      create_post_install_hook
      create_pre_uninstall_hook
    end
  end

  private

  def gem_install(name, version = nil)
    v = version.nil? ? nil : "--version #{version}"
    begin
      cleanenv_safesystem "#{destdir}/bin/gem query --installed --name-matches '^#{name}$' #{v}"
    rescue
      cachedir('gems/cache').mkdir
      if not File.exist? cachedir("gems/cache/#{name}-#{version}.gem")
        cleanenv_safesystem "#{destdir}/bin/gem install --install-dir #{cachedir('gems')} --no-document #{v} #{name}"
      end
      Dir.chdir cachedir('gems/cache') do
        cleanenv_safesystem "#{destdir}/bin/gem install --local --no-document #{v} #{name}"
      end
    end
  end

  def bundle_prepare(gemfile, gemfile_lock = nil)
    # Only if there is no prepared cache
    if not Dir.exist? cachedir("#{gemfile}/vendor/cache")
      cachedir(gemfile).mkdir
      cachedir(gemfile).install workdir(gemfile), 'Gemfile'
      cachedir(gemfile).install workdir(gemfile_lock), 'Gemfile.lock'
      begin
        Dir.chdir cachedir(gemfile) do
          cleanenv_safesystem "#{destdir}/bin/bundle package --all"
        end
      rescue
        # Cleanup if we fail, better than leaving stuff ...
        rm_f cachedir(gemfile)
      end
    end
  end

  def bundle_install(gemfile)
    # We only install the bundle if it is cached
    if Dir.exist? cachedir("#{gemfile}/vendor/cache")
      Dir.chdir cachedir(gemfile) do
        cleanenv_safesystem "#{destdir}/bin/bundle install --local --no-cache --system"
      end
    end
  end

  platforms [:ubuntu, :debian] do
    def build_files
      # Set the real daemon path in initscript defaults
      system "echo DAEMON=#{destdir}/bin/puppet >> ext/debian/puppet.default"
    end
    def install_files
      etc('puppet').mkdir
      etc('puppet').install 'ext/debian/puppet.conf' => 'puppet.conf'
      etc('init.d').install 'ext/debian/puppet.init' => 'puppet'
      etc('default').install 'ext/debian/puppet.default' => 'puppet'
      chmod 0755, etc('init.d/puppet')
    end
  end

  platforms [:fedora, :redhat, :centos] do
    def build_files
      # Set the real daemon path in initscript defaults
      safesystem "echo PUPPETD=#{destdir}/bin/puppet >> ext/redhat/client.sysconfig"
    end
    def install_files
      etc('puppet').mkdir
      etc('puppet').install 'ext/redhat/puppet.conf' => 'puppet.conf'
      etc('init.d').install 'ext/redhat/client.init' => 'puppet'
      etc('sysconfig').install 'ext/redhat/client.sysconfig' => 'puppet'
      chmod 0755, etc('init.d/puppet')
    end
  end

  def create_post_install_hook
    File.open(builddir('post-install'), 'w', 0755) do |f|
      f.write <<-__POSTINST
#!/bin/sh
set -e

BIN_PATH="#{destdir}/bin"
BINS="puppet facter hiera"

for BIN in $BINS; do
  update-alternatives --install /usr/bin/$BIN $BIN $BIN_PATH/$BIN 100
done

exit 0
      __POSTINST
    end
  end

  def create_pre_uninstall_hook
    File.open(builddir('pre-uninstall'), 'w', 0755) do |f|
      f.write <<-__PRERM
#!/bin/sh
set -e

BIN_PATH="#{destdir}/bin"
BINS="puppet facter hiera"

if [ "$1" != "upgrade" ]; then
  for BIN in $BINS; do
    update-alternatives --remove $BIN $BIN_PATH/$BIN
  done
fi

exit 0
      __PRERM
    end
  end

end
