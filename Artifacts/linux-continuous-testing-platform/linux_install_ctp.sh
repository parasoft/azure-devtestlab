#!/bin/bash
echo "Installing Oracle JDK"
echo "====================="

if [ ! -d /usr/downloads ]; then
   mkdir /usr/downloads
fi

if [ ! -f /usr/downloads/jdk-8u92-linux-x64.tar.gz ]; then
   wget --quiet --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" -O /usr/downloads/jdk-8u92-linux-x64.tar.gz http://download.oracle.com/otn-pub/java/jdk/8u92-b14/jdk-8u92-linux-x64.tar.gz
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

echo "Download CTP distribution"
curl --silent --location --remote-name http://parasoft.westus.cloudapp.azure.com/builds/parasoft_environment_manager_2.7.5.zip

echo "Install zip and unzip"
if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"

    apt-get -y install zip unzip

elif [ -f /usr/bin/yum ] ; then 
    echo "Using YUM package manager"

    yum clean all

    yum install -y zip unzip
fi

echo "Unzip CTP distribution"
mkdir ctp_dist
unzip parasoft_environment_manager_2.7.5.zip -d ctp_dist/

echo "Copy CTP war files to Tomcat webapps"
cp ctp_dist/pstsec.war $CATALINA_HOME/webapps/
cp ctp_dist/licenseserver.war $CATALINA_HOME/webapps/
mkdir $CATALINA_HOME/webapps/em
unzip ctp_dist/em.war -d $CATALINA_HOME/webapps/em/
cp license $CATALINA_HOME/webapps/em/
cp database.properties $CATALINA_HOME/webapps/em/WEB-INF/classes/META-INF/spring/
echo '<% response.sendRedirect("/em"); %>' >> /opt/tomcat/webapps/ROOT/index.jsp
chown -R tomcat $CATALINA_HOME/webapps/em/

echo "Remove temporary installation files"
rm -rf ctp_dist
rm parasoft_environment_manager_2.7.5.zip

echo "Startup Tomcat"

if [ -f /usr/sbin/update-rc.d ] ; then
    /etc/init.d/tomcat.sh start
elif [ -f /bin/systemctl ] ; then
    systemctl start tomcat
else
    su - tomcat -c $CATALINA_HOME/bin/startup.sh
fi

echo "Configure iptables to forward port 80 to 8080"

iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 80 -j REDIRECT --to-port 8080
iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 443 -j REDIRECT --to-port 8443

if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"

    export DEBIAN_FRONTEND="noninteractive"
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
    apt-get -y install iptables-persistent

elif [ -f /usr/bin/yum ] ; then 
    echo "Using YUM package manager"

    yum install -y iptables-services
    systemctl enable iptables
    service iptables save
    systemctl start iptables
fi

echo "waiting for tomcat startup"
curl --silent --location http://localhost:8080/em
echo "tomcat started"