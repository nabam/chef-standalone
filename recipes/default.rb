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
 'file', 'haveged', 'iftop', 'unzip', 'fail2ban', "wireguard"
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

# systemd units for containers
['iptables-restore.service'].each do |unit|
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
