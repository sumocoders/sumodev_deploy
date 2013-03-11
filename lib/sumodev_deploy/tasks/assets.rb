Capistrano::Configuration.instance.load do
  namespace :assets do
    desc "Compile and upload the CSS files"
    task :precompile do
      compass_folders = fetch(:compass_folders, Dir.glob('**/config.rb'))
      asset_path      = fetch(:asset_cache_dir, Dir.pwd + "/cache/cached_assets")
      output_style   = fetch(:compass_output, :compressed)

      compass_folders.each do |config|
        path = File.dirname(config)

        run_locally "rm -rf #{asset_path} && mkdir -p #{asset_path}" # Cleanup
        run_locally "cd #{path} && compass clean --css-dir #{asset_path}/css && compass compile -s #{output_style} --css-dir #{asset_path}/css"

        assets  = Dir.glob(asset_path + '/*/*').map {|f| [f, f.gsub(asset_path, '')] }
        sprites = Dir.glob(path + "/images/**/*").grep(/-[0-9a-z]{11}.(png|jpg)/).map {|f| [f, f.gsub(path, '')] }

        (assets + sprites).each do |file, filepath|
          upload file, "#{latest_release.shellescape}/#{path}#{filepath}"
        end
      end
    end
  end
end
