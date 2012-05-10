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

      desc "Imports the database from the server into your local database"
      task :get, :roles => :db do
        # @todo Defv would be nice if this also worked on production server. I think we need some extra vars in the capfile for username, password and host. by default these can be the values used on the dev-server.
        system %{mysqladmin create #{db_name}}	# @todo Defv ignore errors
        system %{ssh sites@dev.sumocoders.eu mysqldump --set-charset #{db_name} | mysql #{db_name}}
      end

      desc "Get database info"
      task :info, :roles => :db do
        run "info_db #{db_name}"
      end

      desc "Imports the database from your local server to the remote one"
      task :put, :roles => :db do
        # @todo Defv would be nice if this also worked on production server. I think we need some extra vars in the capfile for username, password and host. by default these can be the values used on the dev-server.
        system %{ssh sites@dev.sumocoders.eu "mysqldump --set-charset #{$db_name} > #{current_path}/#{release_name}.sql" }
      	system %{mysqldump --set-charset #{db_name} | ssh sites@dev.sumocoders.eu mysql #{db_name}}
      end
    end
    
    namespace :files do
      def find_folder_in_parents(folder)
        require 'pathname'

        path = Pathname.pwd
        begin
          found = Pathname.glob(path + folder)
          return found.first if found.any?

          path = path.parent
        end until path.root?
      end

      desc "Sync all remote files to your local install"
      task :get, :roles => :app do
        path = find_folder_in_parents('frontend/files')
        if !path
            raise "No frontend/files folder found in this or upper folders. Are you sure you're in a Fork project?"
        else
            system %{rsync -rltp #{user}@dev.sumocoders.eu:#{shared_path}/files/ #{path}}
        end
      end

      desc "Sync your local files to the remote server"
      task :put, :roles => :app do
        # create a backup on the remote, store it under the release-folder, so it will be automagically removed
        run %{cd #{shared_path} && tar -czf #{current_path}/backup_files.tgz files}

        # check if folder exists
        path = find_folder_in_parents('frontend/files')
        if !path
            raise "No frontend/files folder found in this or upper folders. Are you sure you're in a Fork project?"
        else
          system %{rsync -rltp #{path} #{user}@dev.sumocoders.eu:#{shared_path}/files}
        end
      end
    end
    
    namespace :redirect do
      desc "Installs the redirect page for the site"
      task :put, :roles => :app do
        unless exists?(:production_url)
          fetch(:production_url) do
            Capistrano::CLI.ui.ask "What is the production url?"
          end
        end

        run %{
          mkdir -p #{shared_path}/redirect &&
          wget --quiet -O #{shared_path}/redirect/index.php http://static.sumocoders.be/redirect/index.phps && 
          wget --quiet -O #{shared_path}/redirect/.htaccess http://static.sumocoders.be/redirect/htaccess
        }

        # change the url
        run "if [ -f #{shared_path}/redirect/index.php ]; then sed -i 's|<real-url>|#{production_url}|' #{shared_path}/redirect/index.php; fi"

        run %{
          rm -f #{current_path} &&
          ln -s #{shared_path}/redirect #{current_path}
        }
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
