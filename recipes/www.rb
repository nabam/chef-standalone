#
# Cookbook:: standalone
# Recipe:: default

# Copyright:: 2017, The Authors, All Rights Reserved.

# docker volumes
['nginx-config'].each do |volume|
  docker_volume volume
end

# systemd units for containers
['docker-nginx.service'].each do |unit|
  template "/etc/systemd/system/#{unit}" do
    source "etc/systemd/system/#{unit}.erb"
    variables({
      timezone:   node['systemd']['timezone'],
      fqdn:       node['fqdn'],
      hostname:   node['hostname'],
      url:        node['nginx']['url'],
      email:      node['nginx']['email'],
      uid:        node['media']['uid'],
      gid:        node['media']['gid'],
      plex_claim: node['plex']['claim'],
    })
    notifies :run, 'execute[systemctl daemon-reload]'
  end
end

# website
directory '/var/lib/docker/volumes/nginx-config/_data' do
  recursive true
end

git '/var/lib/docker/volumes/nginx-config/_data/www' do
  repository 'https://github.com/nabam/nabam.github.io.git'
  revision 'master'
  action :export
end

directory '/var/lib/docker/volumes/nginx-config/_data/www/speedtest' do
  recursive true
end

remote_file '/var/lib/docker/volumes/nginx-config/_data/www/speedtest/speedtest_worker.js' do
  source 'https://raw.githubusercontent.com/librespeed/speedtest/master/speedtest_worker.js'
  action :create
end

remote_file '/var/lib/docker/volumes/nginx-config/_data/www/speedtest/speedtest.js' do
  source 'https://raw.githubusercontent.com/librespeed/speedtest/master/speedtest.js'
  action :create
end

template '/var/lib/docker/volumes/nginx-config/_data/www/speedtest/index.html' do
  source   'volumes/nginx-config/www/speedtest/index.html.erb'
end

execute 'dd if=/dev/urandom of=/var/lib/docker/volumes/nginx-config/_data/www/speedtest/payload bs=1024 count=$((1024*50))' do
  not_if { File.exist?('/var/lib/docker/volumes/nginx-config/_data/www/speedtest/payload') }
end

# start containers
['docker-nginx'].each do |svc|
  service svc do
    action [:enable, :start]
  end
end

# www configuration
template '/var/lib/docker/volumes/nginx-config/_data/nginx/site-confs/default' do
  source   'volumes/nginx-config/nginx/site-confs/default.erb'
  notifies :restart, 'service[docker-nginx]'
end

file '/var/lib/docker/volumes/nginx-config/_data/nginx/.htpasswd' do
  content node['nginx']['htpasswd']
end

file '/var/lib/docker/volumes/nginx-config/_data/fail2ban/jail.local' do
  content ''
  notifies :restart, 'service[docker-nginx]'
end
