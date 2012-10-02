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
  _cset(:shared_files_path) { "#{shared_path}/files/"}
  _cset(:document_root) { "#{homedir}#{client}/#{project}" }
  _cset(:keep_releases) { fetch(:stage, 'production').to_sym == :staging ? 1 : 3 }

  set(:application) { project }
  set(:deploy_to) { "#{homedir}#{app_path}"}

  role(:app) { app_servers }
  role(:web) { web_servers }
  role(:db, :primary => true) { db_server }

  after 'deploy', 'deploy:cleanup', 'sumodev:errbit:after_deploy'

  namespace :sumodev do
    namespace :db do
      desc "Create the database. Reads :db_name variable, or it is composed from client / project"
      task :create, :roles => :db do
        run "create_db #{db_name}"
      end

      desc "Dump the remote database, and outputs the content so you can pipe it"
      task :dump, :roles => :db do
        run "mysqldump --set-charset #{db_name}" do |ch, stream, out|
          if stream == :err
            ch[:options][:logger].send(:important, out, "#{stream} :: #{ch[:server]}" )
          else
            print out
          end
        end
      end

      desc "Imports the database from the server into your local database"
      task :get, :roles => :db do
		real_db_name = (stage.to_sym == :production and !fetch(:production_db, "").empty?) ? production_db : db_name
		options = ""
		if !fetch(:db_host, "").empty? then options += "--host #{db_host} " end
		if !fetch(:db_username, "").empty? then options += "--user=#{db_username} " end
		if !fetch(:db_password, "").empty? then options += "--password=#{db_password} " end

        run_locally %{mysqladmin create #{db_name}} rescue nil

        mysql = IO.popen("mysql #{db_name}", 'r+')
        run "mysqldump --set-charset #{options} #{real_db_name}" do |ch, stream, out|
          if stream == :err
            ch[:options][:logger].send(:important, out, "#{stream} :: #{ch[:server]}" )
          else
            mysql.write out
          end
        end
        mysql.close_write
        puts mysql.read
        mysql.close
      end

      desc "Get database info"
      task :info, :roles => :db do
        run "info_db #{db_name}"
      end

      desc "Imports the database from your local server to the remote one"
      task :put, :roles => :db, :only => {:primary => true} do
		real_db_name = (stage.to_sym == :production and !fetch(:production_db, "").empty?) ? production_db : db_name
		options = ""
		if !fetch(:db_host, "").empty? then options += "--host #{db_host} " end
		if !fetch(:db_username, "").empty? then options += "--user=#{db_username} " end
		if !fetch(:db_password, "").empty? then options += "--password=#{db_password} " end

        run "mysqldump --set-charset #{options} #{real_db_name} > #{current_path}/#{release_name}.sql" rescue nil

        dump = StringIO.new(run_locally "mysqldump --set-charset #{db_name}")
        dump_path = "#{shared_path}/db_upload.tmp.sql"
        upload dump, dump_path

        run %{
          mysql #{options} #{real_db_name} < #{dump_path} &&
          rm #{dump_path}
        }
      end
    end

    namespace :errbit do
      task :after_deploy, :rolse => :app do
        update_api_key
        notify
      end
      desc "Updates the Errbit API key"
      task :update_api_key, :roles => :app do
        next if fetch(:production_errbit_api_key, "").empty?
        run "if [ -f #{shared_path}/config/library/globals.php ]; then sed -i \"s/define('ERRBIT_API_KEY', '.*');/define('ERRBIT_API_KEY', '#{production_errbit_api_key}');/\" #{shared_path}/config/library/globals.php; fi"
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

      def rsync(direction, from, to, options = {})
        servers = find_servers_for_task(current_task)
        servers = [servers.first] if options[:once]

        servers.each do |server|
          host_definition = "#{server.user || user}@#{server.host}"
          host_definition << ":#{server.port}" if server.port && server.port != 22

          case direction
          when :down
            run_locally "rsync -rtlpv #{host_definition}:#{from} #{to}"
          when :up
            run_locally "rsync -rtlp #{from} #{host_definition}:#{to}"
          end
        end
      end

      desc "Sync all remote files to your local install"
      task :get, :roles => :app do
        path = find_folder_in_parents('frontend/files')
        if !path
          abort "No frontend/files folder found in this or upper folders. Are you sure you're in a Fork project?"
        else
          rsync :down, shared_files_path, path, :once => true
        end
      end

      desc "Sync your local files to the remote server"
      task :put, :roles => :app do
        # create a backup on the remote, store it under the release-folder, so it will be automagically removed
        run %{cd #{shared_path} && tar -czf #{current_path}/backup_files.tgz files}

        # check if folder exists
        path = find_folder_in_parents('frontend/files')
        if !path
          abort "No frontend/files folder found in this or upper folders. Are you sure you're in a Fork project?"
        else
          rsync :up, "#{path}/", shared_files_path
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
