Capistrano::Configuration.instance.load do
  namespace :opcache do
    namespace :file do
      desc "Reset the opcache thru a PHP-file"
      task :reset do
        run %{
            touch #{current_path}/php-opcache-reset.php
            && echo "<?php clearstatcache(true); if (function_exists('opcache_reset')) { opcache_reset(); }" > #{current_path}/php-opcache-reset.php
            && curl -L --fail --silent --show-error "#{site_url}/php-opcache-reset.php"
            && rm #{current_path}/php-opcache-reset.php
        }
      end
    end

    namespace :phpfpm do
      desc "Installs cachetool.phar to the shared directory"
      task :install_executable do
        run %{
            if [ ! -e #{shared_path}/cachetool.phar ]; then
              cd #{shared_path};
              curl -sO http://gordalina.github.io/cachetool/downloads/cachetool.phar;
              chmod +x cachetool.phar;
            fi
        }
      end

      desc "Reset the opcache with the cachetool.phar"
      task :reset do
        opcache.phpfpm.install_executable
        run %{#{php_bin} #{shared_path}/cachetool.phar opcache:reset --fcgi=#{cachetool_connection_string}}
      end
    end
  end
end
