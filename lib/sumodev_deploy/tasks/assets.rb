Capistrano::Configuration.instance.load do
  namespace :assets do
    desc "Compile and upload the CSS files"
    task :precompile do
      require 'compass'

      compass_folders = fetch(:compass_folders, Dir.glob('**/config.rb'))
      asset_path      = fetch(:asset_cache_dir, Dir.pwd + "/cache/cached_assets")
      output_style   = fetch(:compass_output, :compressed)

      compass_folders.each do |config|
        path = File.dirname(config)
        Compass.add_project_configuration(config)

        run_locally "rm -rf #{asset_path} && mkdir -p #{asset_path}" # Cleanup
        run_locally "cd #{path} && compass clean --css-dir #{asset_path}/#{Compass.configuration.css_dir} && compass compile -s #{output_style} --css-dir #{asset_path}/#{Compass.configuration.css_dir}"

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
      end
    end
  end
end
