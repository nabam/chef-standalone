#
# Cookbook:: standalone
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.

include_recipe "systemd::timezone"

user 'media' do
  uid '1001'
  gid '1001'
  home '/home/media'
  shell '/bin/false'
  manage_home :create
end

["docker.io", "sysdig", "sysdig-dkms", "bash-completion",
 "linux-headers-generic", "git", "apache2-utils", "tcpdump",
 "htop", "transmission-remote-cli", "tcpdump", "dnsutils",
 "silversearcher-ag", "tree", "file"].each do |pkg|
  package pkg
end

["docker-nginx.service", "docker-openvpn@.service",
 "docker-plex.service", "docker-transmission.service"].each do |unit|
  template "/etc/systemd/system/#{unit}" do
    source "etc/systemd/system/#{unit}.erb"
    variables({
      timezone: node["systemd"]["timezone"],
      hostname: node["hostname"],
      url: node["nginx"]["url"],
      email: node["nginx"]["email"],
      uid: 1001,
      gid: 1001,
      plex_claim: node["plex"]["claim"]
    })
  end
end

["docker-nginx.service", "docker-openvpn@#{node["openvpn"]["fqdn"]}.service",
 "docker-plex.service", "docker-transmission.service"].each do |unit|
  service unit do
    action [:enable, :start]
  end
end
