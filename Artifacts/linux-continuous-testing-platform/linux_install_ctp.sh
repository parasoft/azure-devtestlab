#!/bin/bash

#cmd line argument that specifies to install ParaBank demo
IS_DEMO=$1

#JAVA_HOME points to the OpenJDK 17 binaries
export JAVA_HOME=/usr/lib/jvm/jre-17-openjdk

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
  echo "Installing OpenJDK"
  echo "==============================================="
  if [ -d /usr/lib/jvm/jre-17-openjdk ]; then
    echo "OpenJDK already installed"
    return 0
  fi
  if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"

    apt-get -y install openjdk-17-jdk
  elif [ -f /usr/bin/amazon-linux-extras ] ; then
    echo "Using Amazon Corretto java-17"

  yum install -y java-17-amazon-corretto-devel
  elif [ -f /usr/bin/yum ] ; then
    echo "Using YUM package manager"

    yum install -y java-17-openjdk
  fi
  echo "export JAVA_HOME=/usr/lib/jvm/jre-17-openjdk" > /etc/profile.d/java.sh
  source /etc/profile.d/java.sh
  version=$($JAVA_HOME/bin/java -version 2>&1 | awk -F '"' '/version/ {print $2}')
  echo $version
  echo "==============================================="
}

installTomcat() {
  echo "Installing CTP Tomcat instance"
  echo "==============================================="

  TOMCAT_VERSION=10.1.31
  if [ -d $CATALINA_HOME ]; then
    echo "tomcat package already found in target directory"
  else 
    echo "Downloading and unpacking tomcat 10 tar"
    curl --silent --location --remote-name https://archive.apache.org/dist/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
    tar xvzf apache-tomcat-$TOMCAT_VERSION.tar.gz
    mv apache-tomcat-$TOMCAT_VERSION $CATALINA_HOME
    if [ -f /usr/sbin/restorecon ] ; then
      sudo /usr/sbin/restorecon -R -v $CATALINA_HOME/bin
    fi
  fi
  echo "creating CTP tomcat instance"
  mkdir -p $CATALINA_BASE
  mkdir $CATALINA_BASE/conf
  mkdir $CATALINA_BASE/logs
  mkdir $CATALINA_BASE/temp
  mkdir $CATALINA_BASE/webapps
  mkdir $CATALINA_BASE/work
  cp $CATALINA_HOME/conf/logging.properties $CATALINA_BASE/conf/
  cp $CATALINA_HOME/conf/server.xml $CATALINA_BASE/conf/
  if [[ "$IS_DEMO" = "true"  ]]; then
   cp tomcat-users.xml $CATALINA_BASE/conf/
  fi
  cp $CATALINA_HOME/conf/web.xml $CATALINA_BASE/conf/
  cp -r $CATALINA_HOME/webapps/* $CATALINA_BASE/webapps/
  echo "configure CTP CATALINA_BASE permissions"
  groupadd parasoft
  if [ -f /bin/nologin ] ; then
    useradd -M -s /bin/nologin -g parasoft -d $CATALINA_BASE ctp
  elif [ -f /sbin/nologin ] ; then
    useradd -M -s /sbin/nologin -g parasoft -d $CATALINA_BASE ctp
  else
    useradd -M -s /bin/false -g parasoft -d $CATALINA_BASE ctp
  fi
  mkdir -p $CATALINA_BASE/conf/Catalina/localhost
  chgrp -R parasoft $CATALINA_HOME
  chmod g+rwx $CATALINA_BASE
  chmod g+rwx $CATALINA_BASE/conf
  chmod g+r $CATALINA_BASE/conf/*
  chown -R ctp:parasoft $CATALINA_BASE

  if [ -f /bin/systemctl ] ; then
    echo "Using Systemd to register Tomcat as a service"

    cp ctp.service /etc/systemd/system/ctp.service
    chmod 644 /etc/systemd/system/ctp.service
    systemctl daemon-reload
    systemctl enable ctp
  elif [ -f /usr/sbin/update-rc.d ] ; then
    echo "Using Update-rc to register Tomcat as a service"

    cp ctp.sh /etc/init.d/
    chmod 755 /etc/init.d/ctp.sh
    update-rc.d ctp.sh defaults
  elif [ -f /sbin/chkconfig ] ; then
    echo "Using chkconfig to register Tomcat as a service"

    cp ctp.sh /etc/init.d/ctp
    chmod 755 /etc/init.d/ctp
    /sbin/chkconfig ctp on
  fi

  if [ -f apache-tomcat-$TOMCAT_VERSION.tar.gz ]; then
    echo "remove tomcat 10 tar"
    rm apache-tomcat-$TOMCAT_VERSION.tar.gz
  fi
  echo "==============================================="
}

installCTP() {
  echo "Installing CTP"
  echo "==============================================="
  echo "Download CTP distribution"
  curl --silent --location --remote-name http://parasoft.westus.cloudapp.azure.com/builds/parasoft_continuous_testing_platform.zip
  echo "Download licenseserver.war"
  curl --silent --location --remote-name http://parasoft.westus.cloudapp.azure.com/builds/licenseserver.war
  echo "Download pstsec.war"
  curl --silent --location --remote-name http://parasoft.westus.cloudapp.azure.com/builds/pstsec.war
  echo "Unzip CTP distribution"
  mkdir ctp_dist
  unzip parasoft_continuous_testing_platform.zip -d ctp_dist/
  VIRTUALIZE_HOME=/usr/local/parasoft/virtualize

  echo "Copy CTP war files to Tomcat webapps"
  cp pstsec.war $CATALINA_BASE/webapps/
  cp licenseserver.war $CATALINA_BASE/webapps/
  mkdir -p $CATALINA_BASE/LicenseServer/conf
  cp ls.conf $CATALINA_BASE/LicenseServer/conf/
  cp PSTSecConfig.xml  $CATALINA_BASE/LicenseServer/conf/
  mkdir $CATALINA_BASE/webapps/em
  unzip ctp_dist/em.war -d $CATALINA_BASE/webapps/em/
  cp license $CATALINA_BASE/webapps/em/
  cp database.properties $CATALINA_BASE/webapps/em/WEB-INF/classes/META-INF/spring/
  echo '<% response.sendRedirect("/em"); %>' >> /var/tomcat/ctp/webapps/ROOT/index.jsp
  sed -i "s/\${catalina.base}\/logs/\/usr\/local\/parasoft\/virtualize\/workspace\/VirtualAssets\/logs\/ctp/g" $CATALINA_BASE/conf/logging.properties
  chown -R ctp:parasoft $CATALINA_BASE/LicenseServer
  chown -R ctp:parasoft $CATALINA_BASE/webapps/em
  mkdir -p $VIRTUALIZE_HOME/workspace/VirtualAssets/logs/ctp
  chown ctp:parasoft $VIRTUALIZE_HOME/workspace/VirtualAssets/logs/ctp
  chmod 775 $VIRTUALIZE_HOME/workspace/VirtualAssets/logs/ctp

  echo "Remove temporary installation files"
  rm -rf ctp_dist
  rm parasoft_continuous_testing_platform.zip
  echo "==============================================="
}

installParaBankDemo() {
  echo "Installing ParaBank demo"
  echo "==============================================="
  echo "Download parabank.war"
  curl --silent --location --remote-name http://parasoft.westus.cloudapp.azure.com/builds/parabank.war
  echo "Move parabank.war file to Tomcat webapps"
  mv parabank.war $CATALINA_BASE/webapps/
  chown ctp $CATALINA_BASE/webapps/parabank.war
  echo "==============================================="
}

configureTomcatManager() {
  echo "Copy the Tomcat manager webapp to the CTP base"
  cp -r $CATALINA_HOME/webapps/manager $CATALINA_BASE/webapps/
  cp context.xml $CATALINA_BASE/webapps/manager/META-INF/context.xml
  chown -R ctp $CATALINA_BASE/webapps/manager/
  echo "==============================================="
}

configureIPTables() {
  echo "Configure iptables to forward port 80 to 8080"
  echo "==============================================="

  sudo iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 80 -j REDIRECT --to-port 8080
  sudo iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 443 -j REDIRECT --to-port 8443

  if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"
    export DEBIAN_FRONTEND="noninteractive"
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
    apt-get -y install iptables-persistent
  elif [ -f /usr/bin/yum ] ; then 
    if [ -f /bin/systemctl ] ; then
      echo "Using YUM package manager"
      yum install -y iptables-services
      systemctl enable iptables
    fi
    service iptables save
    if [ -f /bin/systemctl ] ; then
      systemctl start iptables
    else
      service iptables restart
    fi
  fi
  echo "==============================================="
}

startTomcat() {
  echo "Startup Tomcat"
  echo "==============================================="
  if [ -f /bin/systemctl ] ; then
    systemctl start ctp
  elif [ -f /usr/sbin/update-rc.d ] ; then
    /etc/init.d/ctp.sh start
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

#install oracle java 17 if not installed 
installJava

#install tomcat 10 if not installed and create CTP tomcat instance
installTomcat

#download CTP zip file and install in tomcat instance
installCTP

#optionally download parabank.war and install in same tomcat as CTP
if [[ "$IS_DEMO" = "true"  ]]; then
  installParaBankDemo
  #configure tomcat for remote scripted deployment of war files
  configureTomcatManager
fi

#configure IP tables to forward port 80 to 8080
configureIPTables

#start tomcat service
#startTomcat
