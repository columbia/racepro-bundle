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

libs = [
  {
    :name => 'linux-2.6-scribe',
    :dependencies => ['make', 'gcc'],
    :build_cmd => ['ln -fs ../config/kernel_config .config', 'make -j4'],
    :install_cmd => ['make install', 'make modules_install',
                     'mkinitramfs -o /boot/initrd.img-2.6.35-scribe+ 2.6.35-scribe+']
  }, {
    :name => 'libscribe',
    :dependencies => 'cmake',
    :work_dir => 'build',
    :build_cmd => ['cmake ..', 'make'],
    :install_cmd => 'make install'
  }, {
    :name => 'py-scribe',
    :dependencies => ['python-dev', 'cython'],
    :build_cmd => ['python setup.py build'],
    :install_cmd => ['python setup.py install']
  }
]

########## Helpers ##########
def copydir(src, dst)
  filename = '/tmp/cap.copy.tar.gz'
  remote_filename = filename
  Dir.chdir(src) { system("tar czf #{filename} *") }
  upload(filename, remote_filename)
  sudo "tar xf #{remote_filename} -C #{dst} && rm #{remote_filename}"
ensure
  File.delete filename rescue nil
end

def install(packages)
  sudo "apt-get -q -y install #{packages.to_a.join(' ')}"
end

########## Tasks ##########
namespace :bootstrap do
  task :users do
    users = Dir.entries('users').select { |d| not d.match('^\.') }
    users.each { |user| sudo "useradd -G admin,sudo -s /bin/bash -m #{user} || true" }
    copydir 'users', '/home'
    users.each { |user| sudo "chown -R #{user}: /home/#{user}" }
  end

  task :dependencies do
    install(['git-core', 'vim-nox'])
    libs.each { |lib| install(lib[:dependencies]) if lib[:dependencies] }
  end

  task :known_hosts do
    run "ssh -o StrictHostKeyChecking=no root@scribe true"
  end

  desc 'bootstrap the server'
  task :default do
    users
    dependencies
    known_hosts
    deploy.setup
  end
end

namespace :deploy do
  task :fix_permissions do
    sudo "chown #{user} -R #{deploy_to}"
  end
  after "deploy:setup", "deploy:fix_permissions"

  task :finalize_update do
    libs.each do |lib|
      work_dir = File.join(latest_release, lib[:name], lib[:work_dir].to_s)
      cmds = lib[:build_cmd].to_a + lib[:install_cmd].to_a.map { |c| "#{sudo} #{c}" }
      run "cd #{work_dir} && #{cmds.join(' && ')}"
    end
  end
end
