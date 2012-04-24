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
    
    namespace :files do
      desc "Sync all remote files to your local install"
      task :get, :roles => :app do
        # check if folder exists, @todo Defv would it be possible to "find" the folder by looping the parent folders?
        path="./frontend/files"
        if !(File.exists?(path) && File.directory?(path))
            raise "The folder ./frontend/files isn't found, execute this task in the root of your project."
        else
            system %{rsync -r #{user}@dev.sumocoders.eu:#{shared_path}/files/ #{path}}
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
        run "if [ -f #{shared_path}/redirect/index.php ]; then sed -i 's/<real-url>/#{production_url.gsub(/['"\\\x0]/,'\\\\\0')}/' #{shared_path}/redirect/index.php; fi"

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
