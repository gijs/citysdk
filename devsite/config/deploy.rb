# require "bundler/capistrano"
puts "*** Deploying to \033[1;41mdev.citysdk.waag.org\033[0m"


set :application, "CSDKDoc"
set :repository,  "."
set :scm, :none


set :branch, "master"

set :deploy_to, "/var/www/dev.citysdk"

set :deploy_via, :copy

set :use_sudo, false
set :user, "citysdk"

default_run_options[:shell] = '/bin/bash'

role :web, "cms.citysdk.waag.org"                          # Your HTTP server, Apache/etc
role :app, "cms.citysdk.waag.org"                          # This may be the same as your `Web` server
role :db,  "cms.citysdk.waag.org", :primary => true       # This is where Rails migrations will run

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  # Assumes you are using Passenger
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end
 
  task :finalize_update, :except => { :no_release => true } do
    run <<-CMD
      rm -rf #{latest_release}/log &&
      mkdir -p #{latest_release}/public &&
      mkdir -p #{latest_release}/tmp &&
      ln -s #{shared_path}/log #{latest_release}/log
    CMD
  end
end  


