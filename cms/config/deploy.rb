set :stages, %w(production testing)
set :default_stage, "testing"
require 'capistrano/ext/multistage'
#require "bundler/capistrano"


set :application, "CsdkCMS"
set :repository,  "."
set :scm, :none


set :branch, "master"

set :deploy_to, "/var/www/csdk_cms"

set :copy_exclude, ['database.json','tmp','filetmp']

set :deploy_via, :copy

set :use_sudo, false
set :user, "citysdk"

default_run_options[:shell] = '/bin/bash'


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
      ln -s #{shared_path}/log #{latest_release}/log &&
      ln -s #{shared_path}/filetmp #{latest_release}/filetmp
    CMD
    run "ln -s /var/www/citysdk/shared/config/database.json #{release_path}"
  end
end  


