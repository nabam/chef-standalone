#
# Cookbook:: standalone
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.

# gandi config
if File.exist?('/etc/default/gandi')
  template '/etc/default/gandi' do
    source 'etc/default/gandi.erb'
  end
end

# set timezone
include_recipe 'systemd::timezone'

# install software
['ipset', 'docker.io', 'sysdig', 'sysdig-dkms', 'bash-completion',
 'linux-headers-generic', 'git', 'apache2-utils', 'tcpdump',
 'htop', 'transmission-remote-cli', 'tcpdump', 'dnsutils',
 'silversearcher-ag', 'tree', 'file'].each do |pkg|
  package pkg
end

service 'docker'

# firewall
template '/etc/systemd/system/iptables-restore.service' do
  source 'etc/systemd/system/iptables-restore.service.erb'
end

service 'iptables-restore' do
  action [:enable]
  notifies :restart, 'service[docker]'
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
service 'sshd'

template '/etc/ssh/sshd_config' do
  source   'etc/ssh/sshd_config.erb'
  notifies :restart, 'service[sshd]'
end

# media
user 'media' do
  uid   1001
  gid   1001
  home  '/home/media'
  shell '/bin/false'
end

# docker volumes
['nginx-config', "ovpn-data-#{node['openvpn']['fqdn']}",
 'plex-config', 'plex-transcode', 'transmission-config'].each do |volume|
  docker_volume volume
end

# init openvpn
script 'init openvpn' do
  code <<-EOH
    docker run -v ovpn-data-#{node['openvpn']['fqdn']}:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u #{node['openvpn']['fqdn']}"
    docker run -v ovpn-data-#{node['openvpn']['fqdn']}:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki
  EOH
  not_if { File.exist?("/var/lib/docker/volumes/ovpn-data-#{node['openvpn']['fqdn']}/_data/openvpn.conf") }
end

# systemd units for containers
['iptables-restore.service', 'docker-nginx.service', 'docker-openvpn@.service',
 'docker-plex.service', 'docker-transmission.service'].each do |unit|
  template "/etc/systemd/system/#{unit}" do
    source "etc/systemd/system/#{unit}.erb"
    variables({
      timezone:   node['systemd']['timezone'],
      fqdn:       node['fqdn'],
      hostname:   node['hostname'],
      url:        node['nginx']['url'],
      email:      node['nginx']['email'],
      uid:        1001,
      gid:        1001,
      plex_claim: node['plex']['claim']
    })
    notifies :run, 'execute[systemctl daemon-reload]'
  end
end

# start containers
['docker-nginx', "docker-openvpn@#{node['openvpn']['fqdn']}",
 'docker-plex', 'docker-transmission'].each do |svc|
  service svc do
    action [:enable, :start]
  end
end

# www configuration
template '/var/lib/docker/volumes/nginx-config/_data/nginx/site-confs/default' do
  source   'volumes/nginx-config/nginx/site-confs/default.erb'
  notifies :restart, 'service[docker-nginx]'
end

git '/var/lib/docker/volumes/nginx-config/_data/www' do
  repository 'https://github.com/nabam/nabam.github.io.git'
  revision 'master'
  action :export
end

directory '/var/lib/docker/volumes/nginx-config/_data/www/speedtest' do
  recursive true
end

remote_file '/var/lib/docker/volumes/nginx-config/_data/www/speedtest/speedtest_worker.min.js' do
  source 'https://raw.githubusercontent.com/adolfintel/speedtest/master/speedtest_worker.min.js'
  action :create
end

template '/var/lib/docker/volumes/nginx-config/_data/www/speedtest/index.html' do
  source   'volumes/nginx-config/www/speedtest/index.html.erb'
end

execute 'dd if=/dev/urandom of=/var/lib/docker/volumes/nginx-config/_data/www/speedtest/payload bs=1024 count=$((1024*50))' do
  not_if { File.exist?('/var/lib/docker/volumes/nginx-config/_data/www/speedtest/payload') }
end

# transmission configuration
template '/var/lib/docker/volumes/transmission-config/_data/settings.json' do
  source   'volumes/transmission-config/settings.json.erb'
  notifies :restart, 'service[docker-transmission]'
end

# openvpn configuration
template "/var/lib/docker/volumes/ovpn-data-#{node['openvpn']['fqdn']}/_data/openvpn.conf" do
  source   'volumes/ovpn-data/openvpn.conf.erb'
  variables({
    fqdn: node['openvpn']['fqdn']
  })
  notifies :restart, "service[docker-openvpn@#{node['openvpn']['fqdn']}]"
end
