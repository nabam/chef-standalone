#
# Cookbook:: standalone
# Recipe:: ssh

service 'sshd'

template '/etc/ssh/sshd_config' do
  source   'etc/ssh/sshd_config.erb'
  notifies :restart, 'service[sshd]'
end

