#!/bin/bash

SHARED_DIR=$1
# shellcheck source=/configs/variables
if [ -f "$SHARED_DIR/configs/variables" ]; then
  # shellcheck disable=SC1091
  . "$SHARED_DIR"/configs/variables
fi

if [ ! -d "$DOWNLOAD_DIR" ]; then
  mkdir -p "$DOWNLOAD_DIR"
fi

# Set apt-get for non-interactive mode
export DEBIAN_FRONTEND=noninteractive

# Update
apt-get -y update && apt-get -y upgrade

# SSH
apt-get -y install openssh-server

# Build tools
apt-get -y install build-essential automake libtool

# Git vim
apt-get -y install git vim

# Java (Oracle)
apt-get install -y software-properties-common
apt-get install -y python-software-properties
add-apt-repository -y ppa:webupd8team/java
apt-get update
#echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
#echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
apt-get install -y openjdk-8-jdk-headless
#update-java-alternatives -s java-8-oracle
#apt-get install -y oracle-java8-set-default

# Set JAVA_HOME variable both now and for when the system restarts
export JAVA_HOME
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:jre/bin/java::")
echo "JAVA_HOME=$JAVA_HOME" >> /etc/environment

# Maven
apt-get -y install maven

# Tomcat
apt-get -y install tomcat8 tomcat8-admin
usermod -a -G tomcat8 ubuntu

# We still need this for the rest of the times Tomcat is run in the other build scripts
sed -i "s|#JAVA_HOME=.*|JAVA_HOME=$JAVA_HOME|g" /etc/default/tomcat8

# Wget and curl
apt-get -y install wget curl

# Bug fix for Ubuntu 14.04 with zsh 5.0.2 -- https://bugs.launchpad.net/ubuntu/+source/zsh/+bug/1242108
export MAN_FILES
MAN_FILES=$(wget -qO- "http://sourceforge.net/projects/zsh/files/zsh/5.0.2/zsh-5.0.2.tar.gz/download" \
  | tar xvz -C /usr/share/man/man1/ --wildcards "zsh-5.0.2/Doc/*.1" --strip-components=2)
for MAN_FILE in $MAN_FILES; do gzip /usr/share/man/man1/"${MAN_FILE##*/}"; done

# Fix for https://github.com/Islandora-Labs/islandora_vagrant/issues/127 
# GhostScript version (9.10) fails to extract PDF pages on RGB format
if [ ! -f "$DOWNLOAD_DIR/ghostscript-$GHOSTSCRIPT_VERSION.tar.gz" ]; then
  echo "Downloading Ghostscript"
  wget -q -O "$DOWNLOAD_DIR/ghostscript-$GHOSTSCRIPT_VERSION.tar.gz" "https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs${GHOSTSCRIPT_VERSION//.}/ghostscript-$GHOSTSCRIPT_VERSION.tar.gz"
fi
cd /tmp || exit
cp "$DOWNLOAD_DIR/ghostscript-$GHOSTSCRIPT_VERSION.tar.gz" /tmp
tar xvzf "ghostscript-$GHOSTSCRIPT_VERSION.tar.gz"
cd "ghostscript-$GHOSTSCRIPT_VERSION" || exit
./configure
make && make install
ln -s /usr/local/bin/gs /usr/bin/gs
ldconfig

# More helpful packages
apt-get -y install htop tree zsh #fish

# Set some params so it's non-interactive for the lamp-server install
debconf-set-selections <<< 'mysql-server mysql-server/root_password password islandora'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password islandora'
debconf-set-selections <<< "postfix postfix/mailname string islandora-vagrant.org"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

# Lamp server
apt-get -y install tasksel
tasksel install lamp-server
usermod -a -G www-data ubuntu

echo "CREATE DATABASE fedora3" | mysql -uroot -pislandora
echo "CREATE USER 'fedoraAdmin'@'localhost' IDENTIFIED BY 'fedoraAdmin'" | mysql -uroot -pislandora
echo "GRANT ALL ON fedora3.* TO 'fedoraAdmin'@'localhost'" | mysql -uroot -pislandora
echo "flush privileges" | mysql -uroot -pislandora

# Add web group, and put some users in it
groupadd web
usermod -a -G web www-data
usermod -a -G web ubuntu
usermod -a -G web tomcat8
