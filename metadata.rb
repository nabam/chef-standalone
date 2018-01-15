name 'standalone'
maintainer 'The Authors'
maintainer_email 'leo@nabam.net'
license 'All Rights Reserved'
description 'Installs/Configures standalone'
long_description 'Installs/Configures standalone'
version '0.1.0'
chef_version '>= 12.11' if respond_to?(:chef_version)

depends "systemd", '= 3.1.5'
depends "docker", '= 3.0.0'
