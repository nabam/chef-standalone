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
['docker-nginx.service', "docker-openvpn@#{node['openvpn']['fqdn']}.service",
 'docker-plex.service', 'docker-transmission.service'].each do |unit|
  service unit do
    action [:enable, :start]
  end
end
