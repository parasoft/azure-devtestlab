#!/bin/bash

###
# Arguments:
#
# $1    Virtualize server name
# $2    CTP base URL
# $3    CTP username
# $4    CTP password
#
###

VIRTUALIZE_SERVER_NAME=$1
CTP_BASE_URL=$2
CTP_USERNAME=$3
CTP_PASSWORD=$4

# parse the URL in bash from http://stackoverflow.com/questions/6174220/parse-url-in-shell-script
# extract the protocol
proto="`echo $CTP_BASE_URL | grep '://' | sed -e's,^\(.*://\).*,\1,g'`"
# remove the protocol
url=`echo $CTP_BASE_URL | sed -e s,$proto,,g`

# extract the user and password (if any)
userpass="`echo $url | grep @ | cut -d@ -f1`"
pass=`echo $userpass | grep : | cut -d: -f2`
if [ -n "$pass" ]; then
    user=`echo $userpass | grep : | cut -d: -f1`
else
    user=$userpass
fi

# extract the host -- updated
hostport=`echo $url | sed -e s,$userpass@,,g | cut -d/ -f1`
port=`echo $hostport | grep : | cut -d: -f2`
if [ -n "$port" ]; then
    host=`echo $hostport | grep : | cut -d: -f1`
else
    host=$hostport
fi

# extract the path (if any)
path="`echo $url | grep / | cut -d/ -f2-`"

CTP_HOST=$host

echo "Installing Oracle JDK"
echo "====================="

if [ ! -d /usr/downloads ]; then
   mkdir /usr/downloads
fi

if [ ! -f /usr/downloads/jdk-8u92-linux-x64.tar.gz ]; then
   wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" -O /usr/downloads/jdk-8u92-linux-x64.tar.gz http://download.oracle.com/otn-pub/java/jdk/8u92-b14/jdk-8u92-linux-x64.tar.gz
fi

if [ -d /usr/oraclejdk ]; then
   rm -rf /usr/oraclejdk
fi
mkdir /usr/oraclejdk
tar -xvf /usr/downloads/jdk-8u92-linux-x64.tar.gz -C /usr/oraclejdk

export JAVA_HOME=/usr/oraclejdk/jdk1.8.0_92
echo "export JAVA_HOME=/usr/oraclejdk/jdk1.8.0_92" > /etc/profile.d/java.sh

if type -p java; then
   version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
   echo $version
fi

if [[ "$version" = "1.8.0_92"  ]]; then
   echo "Oracle JDK installation complete"
else 
   echo "Oracle JDK installation failed" 
fi

echo "Installing Tomcat 8"
echo "====================="

echo "Downloading and unpacking tomcat 8 tar"
TOMCAT_VERSION=8.0.35
curl --silent --location --remote-name http://mirror.nexcess.net/apache/tomcat/tomcat-8/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
tar xvzf apache-tomcat-$TOMCAT_VERSION.tar.gz
mv apache-tomcat-$TOMCAT_VERSION /opt/tomcat
echo "Tomcat 8 environment setup"
export CATALINA_HOME=/opt/tomcat
groupadd tomcat
useradd -M -s /bin/nologin -g tomcat -d /opt/tomcat tomcat
mkdir -p $CATALINA_HOME/conf/Catalina/localhost
chgrp -R tomcat $CATALINA_HOME/conf
chmod g+rwx $CATALINA_HOME/conf
chmod g+r $CATALINA_HOME/conf/*
chgrp tomcat $CATALINA_HOME
chmod g+rwx $CATALINA_HOME
chown -R tomcat $CATALINA_HOME/webapps/ $CATALINA_HOME/work/ $CATALINA_HOME/temp/ $CATALINA_HOME/logs/

if [ -f /usr/sbin/update-rc.d ] ; then
    echo "Using Update-rc to register Tomcat as a service"

    cp tomcat.sh /etc/init.d/
    chmod 755 /etc/init.d/tomcat.sh
    update-rc.d tomcat.sh defaults

elif [ -f /bin/systemctl ] ; then
    echo "Using Systemd to register Tomcat as a service"

    cp tomcat.service /etc/systemd/system/tomcat.service
    systemctl daemon-reload
    systemctl enable tomcat

fi
echo "cleanup"
rm apache-tomcat-$TOMCAT_VERSION.tar.gz
echo "Tomcat 8 installation finished"

echo "Install zip and unzip"
if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"

    apt-get -y install zip unzip

elif [ -f /usr/bin/yum ] ; then 
    echo "Using YUM package manager"

    yum clean all

    yum install -y zip unzip
fi


echo "Download CTS distribution"
curl --silent --location --remote-name http://parasoft.westus.cloudapp.azure.com/builds/parasoft_continuous_testing_service_9.9.5.war

echo "Extract CTS webapp"
VIRTUALIZE_HOME=/usr/local/parasoft/virtualize
mkdir -p $VIRTUALIZE_HOME
unzip parasoft_continuous_testing_service_9.9.5.war -d $VIRTUALIZE_HOME
rm parasoft_continuous_testing_service_9.9.5.war

echo "Configure Tomcat to deploy CTS webapp"
echo "<Context docBase=\"$VIRTUALIZE_HOME\" path=\"\" reloadable=\"true\" />" > $CATALINA_HOME/conf/Catalina/localhost/ROOT.xml
sed -i "s/8080/9080/g" $VIRTUALIZE_HOME/WEB-INF/config.properties
sed -i "s/8443/9443/g" $VIRTUALIZE_HOME/WEB-INF/config.properties
sed -i "s/8080/9080/g" $CATALINA_HOME/conf/server.xml
sed -i "s/8443/9443/g" $CATALINA_HOME/conf/server.xml
sed -i "s/8009/0/g" $CATALINA_HOME/conf/server.xml

sed -i "s/^#env.manager.server.name=.*/env.manager.server.name=$VIRTUALIZE_SERVER_NAME/" $VIRTUALIZE_HOME/WEB-INF/config.properties
sed -i "s!^#env.manager.server=.*!env.manager.server=$CTP_BASE_URL!" $VIRTUALIZE_HOME/WEB-INF/config.properties
sed -i "s/^#env.manager.username=.*/env.manager.username=$CTP_USERNAME/" $VIRTUALIZE_HOME/WEB-INF/config.properties
sed -i "s/^#env.manager.password=.*/env.manager.password=$CTP_PASSWORD/" $VIRTUALIZE_HOME/WEB-INF/config.properties
sed -i "s/^#env.manager.notify=.*/env.manager.notify=true/" $VIRTUALIZE_HOME/WEB-INF/config.properties
sed -i "s/^#virtualize.license.use_network=.*/virtualize.license.use_network=true/" $VIRTUALIZE_HOME/WEB-INF/config.properties
sed -i "s/^#virtualize.license.network.edition=.*/virtualize.license.network.edition=custom_edition/" $VIRTUALIZE_HOME/WEB-INF/config.properties
sed -i "s/^#virtualize.license.custom_edition_features=.*/virtualize.license.custom_edition_features=Server, Validate, Message Packs, Unlimited Hits\/Day, 1 Million Hits\/Day, 500000 Hits\/Day, 100000 Hits\/Day, 50000 Hits\/Day, 25000 Hits\/Day, 10000 Hits\/Day/" $VIRTUALIZE_HOME/WEB-INF/config.properties
sed -i "s/^#license.network.host=.*/license.network.host=$CTP_HOST/" $VIRTUALIZE_HOME/WEB-INF/config.properties
sed -i "s/^#license.network.port=.*/license.network.port=2002/" $VIRTUALIZE_HOME/WEB-INF/config.properties

chown -R tomcat /usr/local/parasoft/virtualize/

echo "Startup Tomcat"

if [ -f /usr/sbin/update-rc.d ] ; then
    /etc/init.d/tomcat.sh start
elif [ -f /bin/systemctl ] ; then
    systemctl start tomcat
else
    su - tomcat -c $CATALINA_HOME/bin/startup.sh
fi
