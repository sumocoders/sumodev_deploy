Capistrano::Configuration.instance.load do
  namespace :assets do
    desc "Compile and upload the assets"
    task :precompile do
      run_locally "grunt build"
      run %{
        rm -rf #{latest_release.shellescape}/src/Frontend/Themes/#{theme}/Core &&
        mkdir -p #{latest_release.shellescape}/src/Frontend/Themes/#{theme}/Core
      }
      upload "./src/Frontend/Themes/#{theme}/Core", "#{latest_release.shellescape}/src/Frontend/Themes/#{theme}/Core"
    end
  end
end
