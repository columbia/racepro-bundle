load 'deploy'

ssh_options[:keys] = 'users/racepro/.ssh/id_rsa'

set :application, 'racepro'
set :scm, :git
set :repository, 'root@scribe:racepro-bundle'
set :branch, 'master'
set :user, 'racepro'
set :scm_verbose, true
set :git_enable_submodules, true

set :deploy_via, :remote_cache
set :deploy_to, "/srv/#{application}"
set :keep_releases, 5

role :racepro, 'racepro'

def copydir(src, dst)
  filename = '/tmp/cap.copy.tar.gz'
  remote_filename = filename
  Dir.chdir(src) { system("tar czf #{filename} *") }
  upload(filename, remote_filename)
  sudo "tar xf #{remote_filename} -C #{dst} && rm #{remote_filename}"
ensure
  File.delete filename rescue nil
end

namespace :bootstrap do
  task :users do
    users = Dir.entries('users').select { |d| not d.match('^\.') }
    users.each { |user| sudo "useradd -G admin,sudo -s /bin/bash -m #{user} || true" }
    copydir 'users', '/home'
    users.each { |user| sudo "chown -R #{user}: /home/#{user}" }
  end

  task :packages do
    sudo "apt-get -q -y install git-core vim-nox"
  end

  desc 'bootstrap the server'
  task :default do
    users
    packages
    deploy.setup
  end
end

namespace :deploy do
  task :fix_permissions do
    sudo "chown #{user} -R #{deploy_to}"
  end

  after "deploy:setup", "deploy:fix_permissions"
end
