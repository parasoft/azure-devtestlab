#!/bin/bash

#JAVA_HOME points to the oracle java 8 binaries
export JAVA_HOME=/usr/oraclejdk/jdk1.8.0_92

#CATALINA_HOME points to the tomcat library files
export CATALINA_HOME=/usr/local/tomcat

#CATALINA_BASE points to the CPT tomcat instance
export CATALINA_BASE=/var/tomcat/ctp

init() {
  echo "Install zip and unzip"
  if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"

    apt-get -y install zip unzip

  elif [ -f /usr/bin/yum ] ; then 
    echo "Using YUM package manager"

    yum clean all

    yum install -y zip unzip
  fi
}

installJava() {
  echo "Installing Oracle JDK"
  echo "==============================================="
  if [ -d /usr/oraclejdk ]; then
    echo "Oracle JDK already installed"
    return 0
  fi
  wget --quiet --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" -O jdk-8u92-linux-x64.tar.gz http://download.oracle.com/otn-pub/java/jdk/8u92-b14/jdk-8u92-linux-x64.tar.gz
  mkdir /usr/oraclejdk
  tar -xvf jdk-8u92-linux-x64.tar.gz -C /usr/oraclejdk
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
  echo "remove jdk tar file"
  rm jdk-8u92-linux-x64.tar.gz
  echo "==============================================="
}

installTomcat() {
  echo "Installing CTP Tomcat instance"
  echo "==============================================="

  TOMCAT_VERSION=8.0.35
  if [ -d /usr/local/tomcat ]; then
    echo "tomcat package already found in target directory"
  else 
    echo "Downloading and unpacking tomcat 8 tar"
    curl --silent --location --remote-name http://mirror.nexcess.net/apache/tomcat/tomcat-8/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
    tar xvzf apache-tomcat-$TOMCAT_VERSION.tar.gz
    mv apache-tomcat-$TOMCAT_VERSION /usr/local/tomcat
  fi
  echo "creating CTP tomcat instance"
  mkdir -p /var/tomcat/ctp
  echo "export CATALINA_BASE=/var/tomcat/ctp" > /etc/profile.d/tomcat.sh
  mkdir $CATALINA_BASE/conf
  mkdir $CATALINA_BASE/logs
  mkdir $CATALINA_BASE/temp
  mkdir $CATALINA_BASE/webapps
  mkdir $CATALINA_BASE/work
  cp $CATALINA_HOME/conf/server.xml $CATALINA_BASE/conf/
  cp $CATALINA_HOME/conf/web.xml $CATALINA_BASE/conf/
  cp -r $CATALINA_HOME/webapps/* $CATALINA_BASE/webapps/
  echo "configure CATALINA_HOME permissions"
  groupadd parasoft
  chgrp -R parasoft $CATALINA_HOME/bin
  chmod g+rwx $CATALINA_HOME/bin
  echo "configure CTP CATALINA_BASE permissions"
  useradd -M -s /bin/nologin -g parasoft -d /var/tomcat/ctp ctp
  mkdir -p $CATALINA_BASE/conf/Catalina/localhost
  chgrp -R parasoft $CATALINA_BASE/conf
  chmod g+rwx $CATALINA_BASE/conf
  chmod g+r $CATALINA_BASE/conf/*
  chgrp parasoft $CATALINA_BASE
  chmod g+rwx $CATALINA_BASE
  chown -R ctp $CATALINA_BASE/webapps/ $CATALINA_BASE/work/ $CATALINA_BASE/temp/ $CATALINA_BASE/logs/

  if [ -f /usr/sbin/update-rc.d ] ; then
    echo "Using Update-rc to register Tomcat as a service"

    cp ctp.sh /etc/init.d/
    chmod 755 /etc/init.d/ctp.sh
    update-rc.d ctp.sh defaults

  elif [ -f /bin/systemctl ] ; then
    echo "Using Systemd to register Tomcat as a service"

    cp ctp.service /etc/systemd/system/ctp.service
    systemctl daemon-reload
    systemctl enable ctp
  fi

  if [ -f apache-tomcat-$TOMCAT_VERSION.tar.gz]; then
    echo "remove tomcat 8 tar"
    rm apache-tomcat-$TOMCAT_VERSION.tar.gz
  fi
  echo "==============================================="
}

installCTP() {
  echo "Installing CTP"
  echo "==============================================="
  echo "Download CTP distribution"
  curl --silent --location --remote-name http://parasoft.westus.cloudapp.azure.com/builds/parasoft_environment_manager_2.7.5.zip
  echo "Unzip CTP distribution"
  mkdir ctp_dist
  unzip parasoft_environment_manager_2.7.5.zip -d ctp_dist/

  echo "Copy CTP war files to Tomcat webapps"
  cp ctp_dist/pstsec.war $CATALINA_BASE/webapps/
  cp ctp_dist/licenseserver.war $CATALINA_BASE/webapps/
  mkdir $CATALINA_BASE/webapps/em
  unzip ctp_dist/em.war -d $CATALINA_BASE/webapps/em/
  cp license $CATALINA_BASE/webapps/em/
  cp database.properties $CATALINA_BASE/webapps/em/WEB-INF/classes/META-INF/spring/
  echo '<% response.sendRedirect("/em"); %>' >> /var/tomcat/ctp/webapps/ROOT/index.jsp
  chown -R ctp $CATALINA_BASE/webapps/em/

  echo "Remove temporary installation files"
  rm -rf ctp_dist
  rm parasoft_environment_manager_2.7.5.zip
  echo "==============================================="
}

configureIPTables() {
  echo "Configure iptables to forward port 80 to 8080"
  echo "==============================================="

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
  echo "==============================================="
}

startTomcat() {
  echo "Startup Tomcat"
  echo "==============================================="
  if [ -f /usr/sbin/update-rc.d ] ; then
    /etc/init.d/ctp.sh start
  elif [ -f /bin/systemctl ] ; then
    systemctl start ctp
  else
    su - ctp -c $CATALINA_HOME/bin/startup.sh
  fi
  echo "waiting for tomcat startup"
  curl --silent --location http://localhost:8080/em
  echo "tomcat started"
  echo "==============================================="
}

#initalize download command utilities needed for CTP installation
init

#install oracle java 8 if not installed 
installJava

#install tomcat 8 if not installed and create CTP tomcat instance
installTomcat

#download CTP zip file and install in tomcat instance
installCTP

#configure IP tables to forward port 80 to 8080
configureIPTables

#start tomcat service
startTomcat