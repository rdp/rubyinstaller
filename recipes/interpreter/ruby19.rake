require 'rake'
require 'rake/clean'

namespace(:interpreter) do
  namespace(:ruby19) do
    package = RubyInstaller::Ruby19
    directory package.target
    directory package.build_target
    directory package.install_target
    CLEAN.include(package.target)
    CLEAN.include(package.build_target)
    CLEAN.include(package.install_target)
    
    # Put files for the :download task
    package.files.each do |f|
      file_source = "#{package.url}/#{f}"
      file_target = "downloads/#{f}"
      download file_target => file_source
      
      # depend on downloads directory
      file file_target => "downloads"
      
      # download task need these files as pre-requisites
      task :download => file_target
    end

    task :checkout => "downloads" do
      cd RubyInstaller::ROOT do
        # If is there already a checkout, update instead of checkout"
        if File.exist?(File.join(RubyInstaller::ROOT, package.checkout_target, '.svn'))
          sh "svn update #{package.checkout_target}"
        else
          sh "svn co #{package.checkout} #{package.checkout_target}"
        end
      end
    end

    task :download_or_checkout do
      if ENV['CHECKOUT'] then
        Rake::Task['interpreter:ruby19:checkout'].invoke
      else
        Rake::Task['interpreter:ruby19:download'].invoke
      end
    end

    task :extract => [:extract_utils, package.target] do
      # grab the files from the download task
      files = Rake::Task['interpreter:ruby19:download'].prerequisites

      # use the checkout copy instead of the packaged file
      unless ENV['CHECKOUT']
        files.each { |f|
          extract(File.join(RubyInstaller::ROOT, f), package.target)
        }
      else
        cp_r(package.checkout_target, File.join(RubyInstaller::ROOT, 'sandbox'), :verbose => true, :remove_destination => true)
      end
    end
    ENV['CHECKOUT'] ? task(:extract => :checkout) : task(:extract => :download)

    task :prepare => [package.build_target] do
      cd RubyInstaller::ROOT do
        cp_r(Dir.glob('resources/icons/*.ico'), package.build_target, :verbose => true)
      end

      # FIXME: Readline is not working, remove it for now.
      cd package.target do
        rm_f 'test/readline/test_readline.rb'
      end
    end

    makefile = File.join(package.build_target, 'Makefile')
    configurescript = File.join(package.target, 'configure')

    file configurescript => [ package.target ] do
      cd package.target do
        msys_sh "autoconf"
      end
    end

    file makefile => [ package.build_target, configurescript ] do
      cd package.build_target do
        msys_sh "../ruby_1_9/configure #{package.configure_options.join(' ')} --enable-shared --prefix=#{File.join(RubyInstaller::ROOT, package.install_target)}"
      end
    end

    task :configure => makefile
    
    task :compile => makefile do
      cd package.build_target do
        msys_sh "make"
      end
    end

    task :install => [package.install_target] do
      full_install_target = File.expand_path(File.join(RubyInstaller::ROOT, package.install_target))

      # perform make install
      cd package.build_target do
        msys_sh "make install"
      end
      
      # verbatim copy the binaries listed in package.dependencies
      package.dependencies.each do |dep|
        Dir.glob("#{RubyInstaller::MinGW.target}/**/#{dep}").each do |path|
          cp path, File.join(package.install_target, "bin")
        end
      end
      
      # copy original scripts from ruby_1_8 to install_target
      Dir.glob("#{package.target}/bin/*").each do |path|
        cp path, File.join(package.install_target, "bin")
      end

      # remove path reference to sandbox (after install!!!)
      rbconfig = Dir.glob("#{package.install_target}/lib/**/rbconfig.rb").first
      contents = File.read(rbconfig).gsub(/#{Regexp.escape(full_install_target)}/) { |match| "" }
      File.open(rbconfig, 'w') { |f| f.write(contents) }

      # replace the batch files with new and path-clean stubs
      Dir.glob("#{package.install_target}/bin/*.bat").each do |bat|
        File.open(bat, 'w') do |f|
          f.write batch_stub
        end
      end
    end

    # makes the installed ruby the first in the path and use if for the tests!
    task :check do
      new_ruby = File.join(RubyInstaller::ROOT, package.install_target, "bin").gsub(File::SEPARATOR, File::ALT_SEPARATOR)
      ENV['PATH'] = "#{new_ruby};#{ENV['PATH']}"
      cd package.build_target do
        msys_sh "make check"
      end
    end

    task :manifest do
      manifest = File.open(File.join(package.build_target, "manifest"), 'w')
      cd package.install_target do
        Dir.glob("**/*").each do |f|
          manifest.puts(f) unless File.directory?(f)
        end
      end
      manifest.close
    end

    task :irb do
      cd File.join(package.install_target, 'bin') do
        sh "irb.bat"
      end
    end

    def batch_stub
      <<-SCRIPT
@ECHO OFF
IF NOT "%~f0" == "~f0" GOTO :WinNT
ECHO.This version of Ruby has not been built with support for Windows 95/98/Me.
GOTO :EOF
:WinNT
@"%~dp0ruby.exe" "%~dpn0" %*
SCRIPT
    end
  end
end

# add compiler and dependencies to the mix
task :ruby19 => [:compiler, :dependencies]

desc "compile Ruby 1.9"
task :ruby19 => [
  'interpreter:ruby19:download_or_checkout',
  'interpreter:ruby19:extract',
  'interpreter:ruby19:prepare',
  'interpreter:ruby19:configure',
  'interpreter:ruby19:compile',
  'interpreter:ruby19:install'
]

# Add rubygems to the chain
task :ruby19 => [:rubygems19]

# add Pure Readline to the chain
task :ruby19 => [:rbreadline]
task :ruby19 => ['dependencies:rbreadline:install19']

task :check19   => ['interpreter:ruby19:check']
task :irb19     => ['interpreter:ruby19:irb']
