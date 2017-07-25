#
# Cookbook:: standalone
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.

["docker.io", "sysdig", "sysdig-dkms", "bash-completion",
 "linux-headers-generic", "git", "apache2-utils", "tcpdump",
 "htop", "transmission-remote-cli", "tcpdump", "dnsutils",
 "silversearcher-ag", "tree", "file"].each do |pkg|
  package pkg
end

