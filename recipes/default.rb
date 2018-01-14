#
# Cookbook:: standalone
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.

apt_update

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
 'git', 'apache2-utils', 'htop', 'transmission-remote-cli',
 'tcpdump', 'dnsutils', 'vim', 'silversearcher-ag', 'tree', 'cron',
 'file', 'haveged', 'iftop', 'vnc4server', 'fluxbox', 'xfonts-base',
 'libxss1', 'libnss3', 'libasound2', 'eterm', 'unzip', 'fail2ban'
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
service 'sshd'

template '/etc/ssh/sshd_config' do
  source   'etc/ssh/sshd_config.erb'
  notifies :restart, 'service[sshd]'
end

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
['nginx-config', "ovpn-data-#{node['openvpn']['fqdn']}",
 'plex-config', 'plex-transcode', 'transmission-config'].each do |volume|
  docker_volume volume
end

# systemd units for containers
['iptables-restore.service', 'docker-nginx.service', 'docker-openvpn@.service',
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
      plex_claim: node['plex']['claim']
    })
    notifies :run, 'execute[systemctl daemon-reload]'
  end
end

# init openvpn
bash 'init openvpn' do
  code <<-EOH
    docker run -v ovpn-data-#{node['openvpn']['fqdn']}:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u #{node['openvpn']['fqdn']}
    docker run -v ovpn-data-#{node['openvpn']['fqdn']}:/etc/openvpn --rm kylemanna/openvpn easyrsa init-pki
    docker run -v ovpn-data-#{node['openvpn']['fqdn']}:/etc/openvpn --rm kylemanna/openvpn sh -c 'echo #{node['openvpn']['fqdn']} | easyrsa build-ca nopass'
    docker run -v ovpn-data-#{node['openvpn']['fqdn']}:/etc/openvpn --rm kylemanna/openvpn easyrsa gen-dh
    docker run -v ovpn-data-#{node['openvpn']['fqdn']}:/etc/openvpn --rm kylemanna/openvpn easyrsa build-server-full #{node['openvpn']['fqdn']} nopass
    docker run -v ovpn-data-#{node['openvpn']['fqdn']}:/etc/openvpn --rm kylemanna/openvpn openvpn --genkey --secret /etc/openvpn/pki/ta.key
  EOH
  not_if { File.exist?("/var/lib/docker/volumes/ovpn-data-#{node['openvpn']['fqdn']}/_data/openvpn.conf") }
end

# openvpn configuration
template "/var/lib/docker/volumes/ovpn-data-#{node['openvpn']['fqdn']}/_data/openvpn.conf" do
  source   'volumes/ovpn-data/openvpn.conf.erb'
  variables({
    fqdn: node['openvpn']['fqdn']
  })
  notifies :restart, "service[docker-openvpn@#{node['openvpn']['fqdn']}]"
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
  notifies :restart, 'service[docker-sickgear]'
end

# start containers
['docker-nginx', "docker-openvpn@#{node['openvpn']['fqdn']}",
 'docker-plex', 'docker-transmission', 'docker-sickgear'].each do |svc|
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

# vnc
user "vnc"

template '/etc/systemd/system/vncserver@.service' do
  source 'etc/systemd/system/vncserver@.service.erb'
  notifies :run, 'execute[systemctl daemon-reload]'
end

directory '/home/vnc/.vnc' do
  recursive true
  owner "vnc"
  group "vnc"
end

template "/home/vnc/.vnc/xstartup" do
  source "vnc/xstartup.erb"
end

service 'vncserver@1010.service' do
  action [:enable, :start]
end

file '/home/vnc/.vnc/passwd' do
  owner "vnc"
  group "vnc"
  content Base64.decode64(node['vnc']['passwd'])
end

# DuckieTV disabled in favor of SickGear
remote_file "/root/DuckieTV-#{node['duckietv']['version']}-ubuntu-x64.deb" do
  source "https://github.com/SchizoDuckie/DuckieTV/releases/download/#{node['duckietv']['version']}/DuckieTV-#{node['duckietv']['version']}-ubuntu-x64.deb"
  action :create
end

dpkg_package 'duckietv' do
  source "/root/DuckieTV-#{node['duckietv']['version']}-ubuntu-x64.deb"
  action :install
end

template '/etc/systemd/system/duckietv.service' do
  source 'etc/systemd/system/duckietv.service.erb'
  notifies :run, 'execute[systemctl daemon-reload]'
end

service 'duckietv.service' do
  action [:disable, :stop]
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
