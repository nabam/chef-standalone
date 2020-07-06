#
# Cookbook:: standalone
# Recipe:: media

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
['plex-config', 'plex-transcode', 'transmission-config'].each do |volume|
  docker_volume volume
end

# systemd units for containers
['docker-plex.service', 'docker-transmission.service', 'docker-sickgear.service'].each do |unit|
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
['docker-plex', 'docker-transmission', 'docker-sickgear'].each do |svc|
  service svc do
    action [:enable, :start]
  end
end

# housekeeping
template '/etc/cron.d/housekeeping' do
  source 'etc/cron.d/housekeeping.erb'
end
