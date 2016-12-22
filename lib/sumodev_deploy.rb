Capistrano::Configuration.instance.load do
  require 'sumodev_deploy/tasks/db'
  require 'sumodev_deploy/tasks/errbit'
  require 'sumodev_deploy/tasks/files'
  require 'sumodev_deploy/tasks/redirect'
  require 'sumodev_deploy/tasks/assets'
  require 'sumodev_deploy/tasks/browse'

  def _cset(name, *args, &block)
    unless exists?(name)
      set(name, *args, &block)
    end
  end

  def staging?
    fetch(:stage, '').to_sym == :staging
  end

  def production?
    fetch(:stage, '').to_sym == :production
  end

  _cset(:client)  { abort "sumodev_deploy requires that you set client and project names in your capfile" }
  _cset(:project) { abort "sumodev_deploy requires that you set client and project names in your capfile"}

  _cset(:db_name) { "#{client[0,8]}_#{project[0,7]}"}
  _cset(:remote_db_name) { db_name }

  _cset(:staging_server, 'dev.sumocoders.be')
  _cset(:production_server, nil)
  _cset(:staging_url) { "#{project}.#{client}.sumocoders.eu" }
  _cset(:production_url, nil)
  _cset(:site_url) { staging? ? staging_url : production_url }
  _cset(:app_servers) { production_server || staging_server }
  _cset(:web_servers) { production_server || staging_server }
  _cset(:db_server)   { production_server || staging_server }
  _cset(:db_lockfile) { "#{shared_path}/db.lock" }

  _cset(:user, 'sites')
  _cset(:homedir) { "/home/#{user}/" }
  _cset(:app_path) { "apps/#{client}/#{project}" }
  _cset(:shared_files_path) { "#{shared_path}/files/"}
  _cset(:document_root) { "#{homedir}#{client}/#{project}" }
  _cset(:keep_releases) { staging? ? 1 : 3 }

  _cset(:php_bin) { "php" }

  set(:application) { project }
  set(:deploy_to) { "#{homedir}#{app_path}"}

  role(:app) { app_servers }
  role(:web) { web_servers }
  role(:db, :primary => true) { db_server }

  after 'deploy', 'deploy:cleanup', 'sumodev:errbit:after_deploy'

  namespace :sumodev do
    namespace :setup do
      desc "Create the client folder if it doesn't exist yet"
      task :client_folder do
        run "mkdir -p `dirname #{document_root}`"
      end
    end
  end

  before 'deploy:setup', 'sumodev:setup:client_folder'
end
