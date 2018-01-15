default['duckietv']['version'] = '1.1.4'

default['media']['uid'] = 1001
default['media']['gid'] = 1001

default['systemd']['timezone'] = 'UTC'

default['nginx'] = {
  'url'      => 'example.com',
  'email'    => 'example@example.com',
  'htpasswd' => ''
}

default['plex']['claim'] = ''
default['openvpn']['fqdn'] = 'vpn.example.com'
default['vnc']['passwd'] = ''

default['trakt']['accounts'] = ''
