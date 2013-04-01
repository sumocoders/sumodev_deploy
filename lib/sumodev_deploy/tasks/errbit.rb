Capistrano::Configuration.instance.load do
  namespace :sumodev do
    namespace :errbit do
      task :after_deploy, :rolse => :app do
        update_api_key
        notify
      end
      desc "Updates the Errbit API key"
      task :update_api_key, :roles => :app do
        next if fetch(:production_errbit_api_key, "").empty?
        run "if [ -f #{shared_path}/config/library/globals.php ]; then sed -i \"s/define('ERRBIT_API_KEY', '.*');/define('ERRBIT_API_KEY', '#{production_errbit_api_key}');/\" #{shared_path}/config/library/globals.php; fi"
        run "if [ -f #{shared_path}/config/parameters.yml ]; then sed -i \"s/sumo.errbit_api_key:.*/sumo.errbit_api_key:    #{production_errbit_api_key}/\" #{shared_path}/config/parameters.yml; fi"
      end
      desc "Notify Errbit about a dqeploy"
      task :notify, :roles => :app do
        next if fetch(:production_errbit_api_key, "").empty?
        require 'active_support/core_ext/object'

        parameters = {
          :api_key => production_errbit_api_key,
          :deploy => {
          :rails_env => stage,
          :local_username => ENV["USER"],
          :scm_repository => repository,
          :scm_revision => current_revision
        }
        }
        run_locally "curl -d '#{parameters.to_query}' https://errors.sumocoders.be/deploys.txt"
      end
    end
  end
end
