Capistrano::Configuration.instance.load do
  namespace :assets do
    desc "Compile and upload the assets"
    task :precompile do
      precompile_js
      precompile_css
    end
    desc "Compile and upload the JS files"
    task :precompile_js do
      coffee_folders = fetch(:coffee_folders, Dir.glob('**/*.coffee'))
      unique_coffee_folders = []

      # loop folder so we only have the unique folders left
      coffee_folders.each do |file|
        path = File.dirname(file)

        if not unique_coffee_folders.include?(path)
         unique_coffee_folders.push(path)
        end
      end

      asset_path = fetch(:asset_cache_dir, Dir.pwd + "/cache/cached_assets")

      unique_coffee_folders.each do |path|
        dir_chunks = path.split('/')
        last_chunk = dir_chunks.last
        watch_dir = dir_chunks[0...-1].join('/')
        remote_path = "#{watch_dir}/js"

        run_locally "rm -rf #{asset_path} && mkdir -p #{asset_path}"
        run_locally "cd #{watch_dir} && coffee -c -o #{asset_path} #{last_chunk}"

        assets  = Dir.glob(asset_path + '/**/*').map {|f| [f, f.gsub(asset_path, '')] }
        (assets).each do |file, filepath|
          if File.directory?(file)
            run "mkdir -p #{latest_release.shellescape}/#{remote_path}/#{filepath}"
          else
            upload file, "#{latest_release.shellescape}/#{remote_path}#{filepath}"
          end
        end
      end

      run_locally "rm -rf #{asset_path}"
    end
    desc "Compile and upload the CSS files"
    task :precompile_css do
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
        run_locally "cd #{path} && #{compass} clean --css-dir #{asset_path}/#{Compass.configuration.css_dir} && #{compass} compile -s #{output_style} --css-dir #{asset_path}/#{Compass.configuration.css_dir}"

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
