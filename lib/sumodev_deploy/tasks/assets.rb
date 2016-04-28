Capistrano::Configuration.instance.load do
  namespace :assets do
    desc "Compile and upload the assets"
    task :precompile do
      if File.exist?("Gruntfile.coffee")
        run_locally "grunt build"
        run %{
          rm -rf #{latest_release.shellescape}/src/Frontend/Themes/#{theme}/Core &&
          mkdir -p #{latest_release.shellescape}/src/Frontend/Themes/#{theme}/Core
        }
        upload "./src/Frontend/Themes/#{theme}/Core", "#{latest_release.shellescape}/src/Frontend/Themes/#{theme}/Core"
      else if File.exist?("gulpfile.js")
        run_locally "gulp build"
        run %{
          rm -rf #{latest_release.shellescape}/src/Frontend/Themes/#{theme}/Core &&
          mkdir -p #{latest_release.shellescape}/src/Frontend/Themes/#{theme}/Core
        }
        upload "./src/Frontend/Themes/#{theme}/Core", "#{latest_release.shellescape}/src/Frontend/Themes/#{theme}/Core"
      else
        logger.important "No Gruntfile.coffee or gulpfile.js found"
      end
    end
  end
end
