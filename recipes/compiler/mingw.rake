require 'rake'
require 'rake/clean'

namespace(:compiler) do
  namespace(:mingw) do
    # mingw needs downloads, sandbox and sandbox/mingw
    package = RubyInstaller::MinGW
    directory package.target
    CLEAN.include(package.target)
    
    # Put files for the :download task
    package.files.each do |f|
      if(f.index('http://') == 0) # start_with? 'http://'
         file_source = f
         file_target = "downloads/#{f.split('/')[-1]}"
      else
        file_source = "#{package.url}/#{f}"
        file_target = "downloads/#{f}"
      end
      download file_target => file_source
      
      # depend on downloads directory
      file file_target => "downloads"
      
      # download task need these files as pre-requisites
      task :download => file_target
    end

    # Prepare the :sandbox, it requires the :download task
    task :extract => [:extract_utils, :download, package.target] do
      # grab the files from the download task
      files = Rake::Task['compiler:mingw:download'].prerequisites

      files.each { |f|
        extract(File.join(RubyInstaller::ROOT, f), package.target)
      }
      if ENV['TDM']
        # the old pthread thing strikes us if we're using 1.9.1
        Dir['**/pthread*.h'].each do |file|
           File.delete file
        end
      end
    end
   
  end
end

task :mingw => ['compiler:mingw:download', 'compiler:mingw:extract']
task :compiler => [:mingw]
