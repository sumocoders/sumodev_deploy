Capistrano::Configuration.instance.load do
  namespace :sumodev do
    namespace :redirect do
      task :check do
        current_symlink = capture("readlink -f #{current_path}").chomp
        if current_symlink == "#{shared_path}/redirect" # Project has redirect set up
          sure = Capistrano::CLI.ui.ask "This application has a redirect page installed. Are you sure you want to override this? (y)es/(n)o"

          if sure !~ /^y(es)?/
            exit 1
          end
        end
      end

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
  end

  before 'deploy', 'sumodev:redirect:check'
end
