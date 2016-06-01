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

REPO_DIR=/opt/DataRepositoryServer-linux-x86_64
sed -i "s/^REPO_HOME=.*/$REPO_DIR/" $REPO_DIR/server.sh

groupadd datarepo
useradd -M -s /bin/nologin -g datarepo -d /opt/DataRepositoryServer-linux-x86_64 datarepo
chgrp -R datarepo $REPO_DIR/bin
chgrp datarepo $REPO_DIR
chmod g+rwx $REPO_DIR
chown -R datarepo $REPO_DIR/bin/ $REPO_DIR/curl/

if [ -f /usr/sbin/update-rc.d ] ; then
    echo "Using Update-rc to register data repository as a service"

    cp $REPO_DIR/server.sh /etc/init.d/
    chmod 755 /etc/init.d/server.sh
    update-rc.d server.sh defaults

elif [ -f /bin/systemctl ] ; then
    echo "Using Systemd to register data repository as a service"

    cp repository.service /etc/systemd/system/repository.service
    systemctl daemon-reload
    systemctl enable repository

fi

echo "start Data Repository server"
if [ -f /usr/sbin/update-rc.d ] ; then
    /etc/init.d/server.sh start
elif [ -f /bin/systemctl ] ; then
    systemctl start repository
else
    su - datarepo -c $REPO_DIR/server.sh start
fi
echo "cleanup"
rm DataRepositoryServer.zip
