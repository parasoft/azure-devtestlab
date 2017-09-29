#!/bin/bash

###
# Arguments:
#
# $1    CTP base URL
# $2    CTP username
# $3    CTP password
#
###

TDM_BASE_URL=$1
TDM_USERNAME=$2
TDM_PASSWORD=$3

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

REPO_DIR=/opt/DataRepositoryServer-linux-x86_64
sed -i 's/^REPO_HOME=.*/REPO_HOME=\/opt\/DataRepositoryServer-linux-x86_64/' /opt/DataRepositoryServer-linux-x86_64/server.sh
sed -i "s!^TDA=.*!TDA=$TDM_BASE_URL!" /opt/DataRepositoryServer-linux-x86_64/server.sh
sed -i "s/^T_USER=.*/T_USER=$TDM_USERNAME/" /opt/DataRepositoryServer-linux-x86_64/server.sh
sed -i "s/^T_PASS=.*/T_PASS=$TDM_PASSWORD/" /opt/DataRepositoryServer-linux-x86_64/server.sh

groupadd parasoft
if [ -f /bin/nologin ] ; then
  useradd -M -s /bin/nologin -g parasoft -d /opt/DataRepositoryServer-linux-x86_64 datarepo
elif [ -f /sbin/nologin ] ; then
  useradd -M -s /sbin/nologin -g parasoft -d /opt/DataRepositoryServer-linux-x86_64 datarepo
else
  useradd -M -s /bin/false -g parasoft -d /opt/DataRepositoryServer-linux-x86_64 datarepo
fi
chgrp parasoft $REPO_DIR
chmod g+rwx $REPO_DIR
chown -R datarepo:parasoft $REPO_DIR

if [ -f /usr/sbin/update-rc.d ] ; then
    echo "Using Update-rc to register data repository as a service"

    cp $REPO_DIR/server.sh /etc/init.d/
    chmod 755 /etc/init.d/server.sh
    update-rc.d server.sh defaults

elif [ -f /bin/systemctl ] ; then
    echo "Using Systemd to register data repository as a service"

    cp datarepo.service /etc/systemd/system/datarepo.service
    systemctl daemon-reload
    systemctl enable datarepo

elif [ -f /sbin/chkconfig ] ; then
    echo "Using chkconfig to register data repository as a service"
    cp datarepo.sh /etc/init.d/datarepo
    chkconfig datarepo on
fi

# echo "start Data Repository server"
# if [ -f /usr/sbin/update-rc.d ] ; then
#     /etc/init.d/server.sh start
# elif [ -f /bin/systemctl ] ; then
#     systemctl start datarepo
# else
#     su - datarepo -c $REPO_DIR/server.sh start
# fi
echo "cleanup"
rm DataRepositoryServer.zip
