# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "sumodev_deploy"
  s.version = "0.4.4"

  s.authors = ["Jan De Poorter"]
  s.date = "2012-04-18"
  s.description = "Deploy to Sumocoders Dev server"
  s.summary = "Deployment for Fork 3.x.x with Capistrano"
  s.email = "info@sumocoders.be"
  # s.extra_rdoc_files = [
  # ]
  s.files = [
    "sumodev_deploy.gemspec",
    "lib/sumodev_deploy.rb",
    "lib/sumodev_deploy/tasks/assets.rb",
    "lib/sumodev_deploy/tasks/db.rb",
    "lib/sumodev_deploy/tasks/errbit.rb",
    "lib/sumodev_deploy/tasks/files.rb",
    "lib/sumodev_deploy/tasks/redirect.rb",
  ]
  s.homepage = "https://github.com/sumocoders/sumodev_deploy"
  s.require_paths = ["lib"]

  s.add_dependency "activesupport"
  s.add_dependency "capistrano"
end

