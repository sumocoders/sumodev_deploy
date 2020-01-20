Capistrano::Configuration.instance.load do
  namespace :cache do
    desc "touch the parameters.yml file"
    task :touch_parameters do
      run "if [ -f #{shared_path}/config/library/globals.php ]; then touch #{shared_path}/config/library/globals.php; fi"
      run "if [ -f #{shared_path}/config/parameters.yml ]; then touch #{shared_path}/config/parameters.yml; fi"
    end
  end
end
