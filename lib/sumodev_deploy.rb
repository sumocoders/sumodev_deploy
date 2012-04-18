configuration = Capistrano::Configuration.respond_to?(:instance) ? Capistrano::Configuration.instance(:must_exist) : Capistrano.configuration(:must_exist)

configuration.load do
  def stop(msg)
    puts "\nStopped! \n\treason: #{msg}"
    exit 1
  end

  def client
    self[:client] || stop("sumodev_deploy requires that you set client and project names in your capfile")
  end

  def project
    self[:project] || stop("sumodev_deploy requires that you set client and project names in your capfile")
  end

  def db_name
    fetch(:db_name) { "#{client[0,8]}_#{project[0,7]}"}
  end

  set :user, 'sites'
  set :application, project
  set :deploy_to,"/home/sites/apps/#{client}/#{application}"
  set :document_root, "/home/sites/#{client}/#{application}"

  server 'dev.sumocoders.eu', :app, :web, :db, :primary => true

  namespace :sumodev do
    namespace :db do
      desc "Create the database. Reads :db_name variable, or it is composed from client / project"
      task :create, :roles => :db do
        run "create_db #{db_name}"
      end

      desc "Get database info"
      task :info, :roles => :db do
        run "info_db #{db_name}"
      end
    end

    namespace :setup do
      desc "Create the client folder if it doesn't exist yet"
      task :client_folder do
        run "mkdir -p `dirname #{document_root}`"
      end
    end
  end

  before 'deploy:setup', 'sumodev:setup:client_folder'
end
