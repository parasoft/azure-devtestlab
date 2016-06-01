#!/bin/bash
echo "Installing Parasoft Data Repository"
echo "==================================="
curl --silent --location --remote-name http://parasoft.westus.cloudapp.azure.com/builds/DataRepositoryServer.zip
echo "Install zip and unzip"
if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"

    apt-get -y install zip unzip

elif [ -f /usr/bin/yum ] ; then 
    echo "Using YUM package manager"

    yum clean all

    yum install -y zip unzip
fi
echo "unziping DataRepository"
unzip DataRepositoryServer.zip -d /opt/
echo "start Data Repository server"
/opt/DataRepositoryServer-linux-x86_64/server.sh start
echo "cleanup"
rm DataRepositoryServer.zip
