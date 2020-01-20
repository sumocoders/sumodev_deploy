Capistrano::Configuration.instance.load do
  namespace :sumodev do
    namespace :errbit do
      task :after_deploy, :rolse => :app do
        update_api_key
      end
      desc "Updates the Errbit API key"
      task :update_api_key, :roles => :app do
        next if fetch(:production_errbit_api_key, "").empty?
        run "if [ -f #{shared_path}/config/library/globals.php ]; then sed -i \"s/define('ERRBIT_API_KEY', '.*');/define('ERRBIT_API_KEY', '#{production_errbit_api_key}');/\" #{shared_path}/config/library/globals.php; fi"
        run "if [ -f #{shared_path}/config/parameters.yml ]; then sed -i \"s/sumo.errbit_api_key:.*/sumo.errbit_api_key:    #{production_errbit_api_key}/\" #{shared_path}/config/parameters.yml; fi"
      end
    end
  end
end
