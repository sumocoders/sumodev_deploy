configuration = Capistrano::Configuration.respond_to?(:instance) ? Capistrano::Configuration.instance(:must_exist) : Capistrano.configuration(:must_exist)

configuration.load do
  def _cset(name, *args, &block)
    unless exists?(name)
      set(name, *args, &block)
    end
  end

  _cset(:client)  { abort "sumodev_deploy requires that you set client and project names in your capfile" }
  _cset(:project) { abort "sumodev_deploy requires that you set client and project names in your capfile"}

  _cset(:db_name) { "#{client[0,8]}_#{project[0,7]}"}

  _cset(:staging_server, 'dev.sumocoders.be')
  _cset(:production_server, nil)
  _cset(:app_servers) { production_server || staging_server }
  _cset(:web_servers) { production_server || staging_server }
  _cset(:db_server)   { production_server || staging_server }

  _cset(:user, 'sites')
  _cset(:homedir) { "/home/#{user}/" }
  _cset(:app_path) { "apps/#{client}/#{project}" }
  _cset(:document_root) { "#{homedir}#{client}/#{project}" }

  set(:application) { project }
  set(:deploy_to) { "#{homedir}#{app_path}"}

  role(:app) { app_servers }
  role(:web) { web_servers }
  role(:db, :primary => true) { db_server }

  namespace :sumodev do
    namespace :db do
      desc "Create the database. Reads :db_name variable, or it is composed from client / project"
      task :create, :roles => :db do
        run "create_db #{db_name}"
      end
      
      desc "Dump the remote database, and outputs the content so you can pipe it"
      task :dump, :roles => :db do
        system %{ssh sites@#{db_server} mysqldump --set-charset #{db_name}}
      end

      desc "Imports the database from the server into your local database"
      task :get, :roles => :db do
        system %{mysqladmin create #{db_name}}	# @todo Defv ignore errors
        system %{ssh sites@#{db_server} mysqldump --set-charset #{db_name} | mysql #{db_name}}
      end

      desc "Get database info"
      task :info, :roles => :db do
        run "info_db #{db_name}"
      end

      desc "Imports the database from your local server to the remote one"
      task :put, :roles => :db do
        system %{ssh sites@#{db_server} "mysqldump --set-charset #{$db_name} > #{current_path}/#{release_name}.sql" }
        system %{mysqldump --set-charset #{db_name} | ssh sites@#{db_server} #{db_name}}
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
          # @todo	Defv use primary?
          system %{rsync -rltp #{user}@#{web_servers.first}:#{shared_path}/files/ #{path}}
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
          # @todo	Defv use primary?
          system %{rsync -rltp #{path} #{user}@#{web_servers.first}:#{shared_path}/files}
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
