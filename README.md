# Standalone server config

## Provision with solo

```
apt update && apt install git curl
curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -v 13
/opt/chef/embedded/bin/gem install berkshelf -v 7.0

git clone git@github.com:nabam/chef-standalone.git
(cd chef-standalone/; /opt/chef/embedded/bin/berks package ../cookbooks.tgz)
cat > solo.json << EOF
{
  "run_list": ["standalone", "standalone::ssh", "standalone::www"],
  "nginx": {"url":"$DOMAIN","email":"$EMAIL","htpasswd":"$HTTP_PASSWD"},
  "plex": {"claim":"$PLEX_CLAIM"},
  "trakt": {"accounts": "$TRAKT_ACCOUNT"}
}
EOF
chef-solo -j solo.json --recipe-url ./cookbooks.tgz
```
