Capistrano::Configuration.instance.load do
  namespace :sumodev do
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
        path = find_folder_in_parents('src/Frontend/Files')
        if !path
          abort "No src/Frontend/Files folder found in this or upper folders. Are you sure you're in a Fork project?"
        else
          rsync :down, shared_files_path, path, :once => true
        end
      end

      desc "Sync your local files to the remote server"
      task :put, :roles => :app do
        # create a backup on the remote, store it under the release-folder, so it will be automagically removed
        run %{cd #{shared_path} && tar -czf #{current_path}/backup_files.tgz files}

        # check if folder exists
        path = find_folder_in_parents('src/Frontend/Files')
        if !path
          abort "No src/Frontend/Files folder found in this or upper folders. Are you sure you're in a Fork project?"
        else
          rsync :up, "#{path}/", shared_files_path
        end
      end
    end
  end
end
