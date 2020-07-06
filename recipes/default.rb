#
# Cookbook:: standalone
# Recipe:: default

# Copyright:: 2017, The Authors, All Rights Reserved.

apt_update "update"

# gandi config
if File.exist?('/etc/default/gandi')
  template '/etc/default/gandi' do
    source 'etc/default/gandi.erb'
  end
end

# set timezone
include_recipe 'systemd::timezone'

# install software
['ipset', 'docker.io', 'sysdig', 'bash-completion', 'tcpdump',
 'linux-headers-generic', 'linux-image-generic', 'sysdig-dkms',
 'git', 'apache2-utils', 'htop', 'transmission-cli',
 'tcpdump', 'dnsutils', 'vim', 'silversearcher-ag', 'tree', 'cron',
 'file', 'haveged', 'iftop', 'unzip', 'fail2ban'
].each do |pkg|
  package pkg
end

service 'docker'

# firewall
template '/etc/systemd/system/iptables-restore.service' do
  source 'etc/systemd/system/iptables-restore.service.erb'
end

service 'iptables-restore' do
  action [:enable]
  notifies :restart, 'service[docker]', :immediate
end

file '/etc/ipset.state'

template '/etc/iptables.rules' do
  source   'etc/iptables.rules.erb'
  notifies :restart, 'service[iptables-restore]'
end

template '/etc/ip6tables.rules' do
  source   'etc/ip6tables.rules.erb'
  notifies :restart, 'service[iptables-restore]'
end

# reload command
execute 'systemctl daemon-reload' do
  action :nothing
end

# ssh
#service 'sshd'
#
#template '/etc/ssh/sshd_config' do
#  source   'etc/ssh/sshd_config.erb'
#  notifies :restart, 'service[sshd]'
#end

# media
group 'media' do
  gid node['media']['gid']
end

user 'media' do
  uid   node['media']['uid']
  gid   node['media']['gid']
  home  '/home/media'
  shell '/bin/false'
end

# docker volumes
['nginx-config', 'plex-config', 'plex-transcode', 'transmission-config'].each do |volume|
  docker_volume volume
end

# systemd units for containers
['iptables-restore.service', 'docker-nginx.service',
 'docker-plex.service', 'docker-transmission.service', 'docker-sickgear.service'].each do |unit|
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

# transmission configuration
template '/var/lib/docker/volumes/transmission-config/_data/settings.json' do
  source   'volumes/transmission-config/settings.json.erb'
end

#website
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

# SickGear
directory "/home/media/sickgear" do
  owner "media"
  group "media"
end

directory "/home/media/shows" do
  owner "media"
  group "media"
end

template '/home/media/sickgear/config.ini' do
  source 'sickgear/config.ini.erb'
  variables({
    trakt: node['trakt']
  })
  owner "media"
  group "media"
  mode "640"
  action [:create_if_missing]
  notifies :restart, 'service[docker-sickgear]'
end

# start containers
['docker-nginx', 'docker-plex', 'docker-transmission', 'docker-sickgear'].each do |svc|
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

# housekeeping
template '/etc/cron.d/housekeeping' do
  source 'etc/cron.d/housekeeping.erb'
end

# fail2ban
service 'fail2ban'

template '/etc/fail2ban/jail.local' do
  source 'etc/fail2ban/jail.local.erb'
  notifies :restart, 'service[fail2ban]'
end

template '/etc/fail2ban/paths-overrides.local' do
  source 'etc/fail2ban/paths-overrides.local.erb'
  notifies :restart, 'service[fail2ban]'
end
