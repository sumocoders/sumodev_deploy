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
      elsif File.exist?("gulpfile.js")
        run_locally "gulp build"
        run %{
          rm -rf #{latest_release.shellescape}/src/Frontend/Themes/#{theme}/Core &&
          mkdir -p #{latest_release.shellescape}/src/Frontend/Themes/#{theme}/Core
        }
        upload "./src/Frontend/Themes/#{theme}/Core", "#{latest_release.shellescape}/src/Frontend/Themes/#{theme}/Core"
      else
        logger.important "No Gruntfile.coffee or gulpfile.js found"
      end
      if File.exists?("package.json")
        run_locally "rm -rf temporary_node_modules; mkdir temporary_node_modules; cp package.json temporary_node_modules; cd temporary_node_modules; npm install --production"
        upload "./temporary_node_modules", "#{latest_release.shellescape}"
        run_locally "rm -rf temporary_node_modules"
      end
    end
  end
end
