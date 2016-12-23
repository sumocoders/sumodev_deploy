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

        # get the PHP version
        php_version = capture("#{php_bin} -v | grep 'PHP [0-9].[0-9].[0-9]' -o -m1")

        # When the version is higher then 5.5 we should reset the opcache and the statcache
        if Gem::Version::new(php_version.sub("PHP ", "")) > Gem::Version::new('5.5')
            run "touch #{document_root}/php-opcache-reset.php"
            # clearstatcache(true) will clear the file stats cache and the realpath cache
            # opache_reset will clear the opcache if this is available
            run "echo \"<?php clearstatcache(true); if (function_exists('opcache_reset')) { opcache_reset(); }\" > #{document_root}/php-opcache-reset.php"
            run %{ curl #{site_url}/php-opcache-reset.php }
            run "rm #{document_root}/php-opcache-reset.php"
        end
      end
    end
  end

  before 'deploy', 'sumodev:redirect:check'
end
