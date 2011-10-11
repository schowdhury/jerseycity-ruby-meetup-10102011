set :application, 'kittybase'
set :repository, "git@github.com:darksheik/kittybase.git"
set :deploy_to, "/home/dpflaster/rails/#{application}"
set :rake, 'rake'

# This change was done enable the ability to deploy a branch to
# staging using the parameters on the command line.
# to deploy mobile, $> cap -S branchto=mobile staging deploy
# to deploy master by default, $> cap staging deploy
begin
  set :branchto, (branchto||'master')
rescue
  set :branchto, 'master'
end

# This change was done to be able to deploy to only one production server
begin
  set :serverto, (serverto||'all')
rescue
  set :serverto, 'all'
end

task :production do
  if ( "#{serverto}" == "all")
    role :web, "#{application}.sameerchowdhury.com"
    role :app, "#{application}.sameerchowdhury.com"
    role :db, "#{application}.sameerchowdhury.com", :primary => true
  else
    role :web, "#{serverto}"
    role :app, "#{serverto}"
    role :db, "#{serverto}", :primary => true
  end

  #set :ssh_options, {:forward_agent => true, :paranoid => false}
  set :deploy_role, 'production'
  set :rails_env, 'production'
  set :branch, "#{branchto}"
end

set :keep_releases, 5

set :user, 'dpflaster'
set :use_sudo, false

set :scm, :git

set :deploy_via, :remote_cache

#set :rake, '/usr/local/bin/rake'

# This will execute the Git revision parsing on the *remote* server rather than locally
set :real_revision, lambda { source.query_revision(revision) { |cmd| capture(cmd) } }

after "deploy:symlink", "deploy:symlink_configs"
after "deploy:symlink_configs", "deploy:symlink_bundle"


namespace :deploy do
  task :migrate do
    run("source /etc/profile; cd #{current_path}; rake RAILS_ENV=#{rails_env} db:migrate")
  end
  
  task :symlink_bundle, :roles => :app, :except => {:no_symlink => true} do
    run <<-CMD
      cd #{release_path} && ln -nfs #{shared_path}/vendor/bundle #{release_path}/vendor/bundle
    CMD
    run "source /etc/profile; cd #{release_path} && bundle install --gemfile #{release_path}/Gemfile --path #{shared_path}/bundle --deployment --quiet --without development test "
  end

  task :symlink_configs, :roles => :app, :except => {:no_symlink => true} do
    run <<-CMD
      cd #{release_path} && ln -s #{shared_path}/config/database.yml #{release_path}/config/database.yml
    CMD
  end
  
  task :start, :roles => :app do
    run "source /etc/profile; source ~/.bash_profile; cd #{current_path}; passenger start -p 9001 -d -e #{rails_env}"
    #run "touch #{current_release}/tmp/restart.txt"
  end

  task :stop, :roles => :app do
    run "source /etc/profile; source ~/.bash_profile; cd #{current_path}; passenger stop -p 9001;"
  end

  task :restart, :roles => :app do
    #run "touch #{current_release}/tmp/restart.txt"
    stop
    start
  end

end

namespace :bundler do
  task :create_symlink, :roles => :app do
    run("cd #{release_path}/vendor; ln -s #{shared_path}/vendor/bundle bundle")
  end
 
  task :bundle_new_release, :roles => :app do
    run "source /etc/profile; source ~/.bash_profile; cd #{release_path} && bundle install --gemfile #{release_path}/Gemfile --path #{shared_path}/bundle --deployment --quiet --without development test "
  end
end
 
after 'deploy:update_code', 'bundler:bundle_new_release'