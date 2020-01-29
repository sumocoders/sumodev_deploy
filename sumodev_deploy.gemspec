# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "sumodev_deploy"
  s.version = "0.10.1"

  s.authors = ["Tijs Verkoyen"]
  s.date = "2020-01-29"
  s.description = "Deploy to Sumocoders Dev server"
  s.summary = "..."
  s.email = "info@sumocoders.be"
  s.files = [
    "sumodev_deploy.gemspec",
    "lib/sumodev_deploy.rb",
    "lib/sumodev_deploy/tasks/assets.rb",
    "lib/sumodev_deploy/tasks/browse.rb",
    "lib/sumodev_deploy/tasks/cache.rb",
    "lib/sumodev_deploy/tasks/db.rb",
    "lib/sumodev_deploy/tasks/errbit.rb",
    "lib/sumodev_deploy/tasks/files.rb",
    "lib/sumodev_deploy/tasks/opcache.rb",
    "lib/sumodev_deploy/tasks/redirect.rb",
  ]
  s.homepage = "https://github.com/sumocoders/sumodev_deploy"
  s.require_paths = ["lib"]

  s.add_dependency "activesupport"
  s.add_dependency "capistrano", "~> 2.15"
end
