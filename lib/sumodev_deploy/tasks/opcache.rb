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
  end
end
