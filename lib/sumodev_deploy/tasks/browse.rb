Capistrano::Configuration.instance.load do
  namespace :sumodev do
    desc "Opens the url in the browser"
    task :browse do
      if site_url.include? '://'
        url = site_url
      else
        url = "http://#{site_url}"
      end

      run_locally "open #{url}"
    end
  end
end
