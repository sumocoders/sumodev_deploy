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

        compass_folders = fetch(:compass_folders, Dir.glob('**/config.rb'))
        if not compass_folders.empty?
          assets.compile_with_compass
        end
      end
      if File.exists?("package.json")
        run_locally "rm -rf temporary_node_modules && mkdir temporary_node_modules && cp package.json temporary_node_modules && cd temporary_node_modules && npm install --production"
        upload "./temporary_node_modules", "#{latest_release.shellescape}"
        run_locally "rm -rf temporary_node_modules"
      end
    end

    desc "Compass compile"
    task :compile_with_compass do
      require 'compass'

      compass = fetch(:compass_command) do
        if File.exists?("Gemfile.lock")
          "bundle exec compass"
        else
          "compass"
        end
      end
      compass_folders = fetch(:compass_folders, Dir.glob('**/config.rb'))
      asset_path      = fetch(:asset_cache_dir, Dir.pwd + "/cache/cached_assets")
      output_style   = fetch(:compass_output, :compressed)

      compass_folders.each do |config|
        path = File.dirname(config)
        Compass.add_project_configuration(config)

        run_locally "rm -rf #{asset_path} && mkdir -p #{asset_path}" # Cleanup
        run_locally "cd #{path} && #{compass} clean --css-dir #{asset_path}/#{Compass.configuration.css_dir}"
        run_locally "cd #{path} && #{compass} compile -s #{output_style} --css-dir #{asset_path}/#{Compass.configuration.css_dir}"

        assets  = Dir.glob(asset_path + '/**/*').map {|f| [f, f.gsub(asset_path, '')] }
        sprites = Dir.glob(path + "/images/**/*").grep(/-[0-9a-z]{11}.(png|jpg)/).map {|f| [f, f.gsub(path, '')] }

        (assets + sprites).each do |file, filepath|
          if File.directory?(file)
            run "mkdir -p #{latest_release.shellescape}/#{path}/#{filepath}"
          else
            upload file, "#{latest_release.shellescape}/#{path}#{filepath}"
          end
        end

        run_locally "rm -rf #{asset_path}"
        Compass.reset_configuration!
      end    end
  end
end
