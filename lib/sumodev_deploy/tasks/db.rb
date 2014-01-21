Capistrano::Configuration.instance.load do
  namespace :sumodev do
    namespace :db do
      def remote_db_name_for_stage
        production? && !fetch(:production_db, '').empty? ?
          production_db :
          remote_db_name
      end

      def remote_db_options
        {:db_host => 'host', :db_username => 'user', :db_password => 'password'}.inject('') do |options, (key, param)|
          value = fetch(key, '')
          options << "--#{param}=#{value} " unless value.empty?
          options
        end
      end

      desc "Create the database. Reads :db_name variable, or it is composed from client / project"
      task :create, :roles => :db do
        run "create_db #{db_name}"
      end

      desc "Get database info"
      task :info, :roles => :db do
        run "info_db #{db_name}"
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
        run_locally %{mysqladmin create #{db_name}} rescue nil

        mysql = IO.popen("mysql #{db_name}", 'r+')
        run "mysqldump --set-charset #{remote_db_options} #{remote_db_name_for_stage}" do |ch, stream, out|
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

      desc "Imports the database from your local server to the remote one"
      task :put, :roles => :db, :only => {:primary => true} do
        begin
          run("test ! -f #{db_lockfile}")
        rescue
          abort "Database has not been updated because the database has been locked"
        end

        force.put
      end

      namespace :force do
        desc "Forced export of your local database to the remote server"
        task :put do
          run "mysqldump --set-charset #{db_name} > #{current_path}/#{release_name}.sql" rescue nil

          dump = StringIO.new(run_locally "mysqldump --set-charset #{db_name}")
          dump_path = "#{shared_path}/db_upload.tmp.sql"
          upload dump, dump_path

          run %{
            mysql #{remote_db_options} #{remote_db_name_for_stage} < #{dump_path} &&
            rm #{dump_path}
          }
        end
      end

      desc "Locks the remote database from pushing"
      task :lock, :roles => :db, :only => {:primary => true} do
        run %{
          echo #{release_name} > #{db_lockfile}
        }
      end

      desc "Unlocks the remote database from pushing"
      task :unlock, :roles => :db, :only => {:primary => true} do
        run %{
          rm #{db_lockfile}
        }
      end
    end
  end
end
