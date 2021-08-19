# add pre-reqs ...
sudo yum install curl which -y
sudo rpm --import https://packages.confluent.io/rpm/6.2/archive.key

# --- add CONFLUENT PLATFORM repository ---
cat <<EOF > /etc/yum.repos.d/confluent.repo
[Confluent.dist]
name=Confluent repository (dist)
baseurl=https://packages.confluent.io/rpm/6.2/$releasever
gpgcheck=1
gpgkey=https://packages.confluent.io/rpm/6.2/archive.key
enabled=1

[Confluent]
name=Confluent repository
baseurl=https://packages.confluent.io/rpm/6.2
gpgcheck=1
gpgkey=https://packages.confluent.io/rpm/6.2/archive.key
enabled=1
EOF

# clear yum cache and install Confluent Platform
sudo yum clean all && sudo yum install confluent-platform -y
