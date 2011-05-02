load 'deploy'

ssh_options[:keys] = 'users/racepro/.ssh/id_rsa'

set :application, 'racepro'
set :scm, :git
set :repository, 'root@scribe:racepro-bundle'
set :branch, 'master'
set :user, 'racepro'
set :deploy_via, :remote_cache
set :scm_verbose, true

set :deploy_to, "/srv/#{application}"

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

  desc 'bootstrap the application'
  task :default do
    users
  end
end
