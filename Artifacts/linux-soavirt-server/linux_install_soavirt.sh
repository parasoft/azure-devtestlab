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

#cmd line argument that specifies the server name
VIRTUALIZE_SERVER_NAME=$1

#cmd line argument points to CTP server
CTP_BASE_URL=$2

#cmd line argument username used when trying to connect to CTP 
CTP_USERNAME=$3

#cmd line argument password used when trying to connect to CTP
CTP_PASSWORD=$4

#JAVA_HOME points to the OpenJDK 17 binaries
export JAVA_HOME=/usr/lib/jvm/jre-17-openjdk

#CATALINA_HOME points to the tomcat library files
export CATALINA_HOME=/usr/local/tomcat

#CATALINA_BASE points to the SOAVirt tomcat instance
export CATALINA_BASE=/var/tomcat/soavirt

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
  echo "Installing SOAVirt Tomcat instance"
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
  echo "creating SOAVirt tomcat instance"
  mkdir -p $CATALINA_BASE
  mkdir $CATALINA_BASE/conf
  mkdir $CATALINA_BASE/logs
  mkdir $CATALINA_BASE/temp
  mkdir $CATALINA_BASE/webapps
  mkdir $CATALINA_BASE/work
  cp $CATALINA_HOME/conf/logging.properties $CATALINA_BASE/conf/
  cp $CATALINA_HOME/conf/server.xml $CATALINA_BASE/conf/
  cp $CATALINA_HOME/conf/tomcat-users.xml $CATALINA_BASE/conf/
  cp $CATALINA_HOME/conf/web.xml $CATALINA_BASE/conf/
  cp -r $CATALINA_HOME/webapps/* $CATALINA_BASE/webapps/
  echo "configure SOAVirt CATALINA_BASE permissions"
  groupadd parasoft
  if [ -f /bin/nologin ] ; then
    useradd -M -s /bin/nologin -g parasoft -d $CATALINA_BASE soavirt
  elif [ -f /sbin/nologin ] ; then
    useradd -M -s /sbin/nologin -g parasoft -d $CATALINA_BASE soavirt
  else
    useradd -M -s /bin/false -g parasoft -d $CATALINA_BASE soavirt
  fi
  mkdir -p $CATALINA_BASE/conf/Catalina/localhost
  chgrp -R parasoft $CATALINA_HOME
  chmod g+rwx $CATALINA_BASE
  chmod g+rwx $CATALINA_BASE/conf
  chmod g+r $CATALINA_BASE/conf/*
  chown -R soavirt:parasoft $CATALINA_BASE

  if [ -f /bin/systemctl ] ; then
    echo "Using Systemd to register SOAVirt as a service"

    cp soavirt.service /etc/systemd/system/soavirt.service
    chmod 644 /etc/systemd/system/soavirt.service
    cp delay.service /etc/systemd/system/delay.service
    chmod 644 /etc/systemd/system/delay.service
    systemctl daemon-reload
    systemctl enable soavirt
    systemctl enable delay
  elif [ -f /usr/sbin/update-rc.d ] ; then
    echo "Using Update-rc to register SOAVirt as a service"

    cp soavirt.sh /etc/init.d/
    chmod 755 /etc/init.d/soavirt.sh
    update-rc.d soavirt.sh defaults
  elif [ -f /sbin/chkconfig ] ; then
    echo "Using chkconfig to register Tomcat as a service"

    cp soavirt.sh /etc/init.d/soavirt
    chmod 755 /etc/init.d/soavirt
    /sbin/chkconfig soavirt on
  fi


  if [ -f apache-tomcat-$TOMCAT_VERSION.tar.gz ]; then
    echo "remove tomcat 10 tar"
    rm apache-tomcat-$TOMCAT_VERSION.tar.gz
  fi
  echo "==============================================="
}

installSOAVirt() {
  echo "Installing SOAVirt war file"
  echo "==============================================="
  echo "Download SOAVirt distribution"
  curl --silent --location --remote-name http://parasoft.westus.cloudapp.azure.com/builds/parasoft_soavirt_server.war

  echo "Extract SOAVirt webapp"
  VIRTUALIZE_HOME=/usr/local/parasoft/virtualize
  mkdir -p $VIRTUALIZE_HOME
  unzip parasoft_soavirt_server.war -d $VIRTUALIZE_HOME
  rm parasoft_soavirt_server.war

  echo "Configure Tomcat to deploy SOAVirt webapp"
  echo "<Context docBase=\"$VIRTUALIZE_HOME\" path=\"\" reloadable=\"true\" />" > $CATALINA_BASE/conf/Catalina/localhost/ROOT.xml
  sed -i "s/\${catalina.base}\/logs/\/usr\/local\/parasoft\/virtualize\/workspace\/VirtualAssets\/logs\/virtualize/g" $CATALINA_BASE/conf/logging.properties
  sed -i "s/8080/9080/g" $VIRTUALIZE_HOME/WEB-INF/config.properties
  sed -i "s/8443/9443/g" $VIRTUALIZE_HOME/WEB-INF/config.properties
  sed -i "s/8080/9080/g" $CATALINA_BASE/conf/server.xml
  sed -i "s/8443/9443/g" $CATALINA_BASE/conf/server.xml
  sed -i "s/8005/8006/g" $CATALINA_BASE/conf/server.xml
  sed -i "s/8009/0/g" $CATALINA_BASE/conf/server.xml

  sed -i "s/^#env.manager.server.name=.*/env.manager.server.name=$VIRTUALIZE_SERVER_NAME/" $VIRTUALIZE_HOME/WEB-INF/config.properties
  sed -i "s!^#env.manager.server=.*!env.manager.server=$CTP_BASE_URL!" $VIRTUALIZE_HOME/WEB-INF/config.properties
  sed -i "s/^#env.manager.username=.*/env.manager.username=$CTP_USERNAME/" $VIRTUALIZE_HOME/WEB-INF/config.properties
  sed -i "s/^#env.manager.password=.*/env.manager.password=$CTP_PASSWORD/" $VIRTUALIZE_HOME/WEB-INF/config.properties
  sed -i "s/^#env.manager.notify=.*/env.manager.notify=true/" $VIRTUALIZE_HOME/WEB-INF/config.properties
  sed -i "s/^#soatest.license.use_network=.*/soatest.license.use_network=true/" $VIRTUALIZE_HOME/WEB-INF/config.properties
  sed -i "s/^#soatest.license.network.edition=.*/soatest.license.network.edition=custom_edition/" $VIRTUALIZE_HOME/WEB-INF/config.properties
  sed -i "s/^#soatest.license.custom_edition_features=.*/soatest.license.custom_edition_features=RuleWizard, Command Line, SOA, Web, Server API Enabled, Jtest Connect, Stub Desktop, Stub Server, Message Packs, Advanced Test Generation 100 Users, Advanced Test Generation 25 Users, Advanced Test Generation 5 Users, Advanced Test Generation Desktop/" $VIRTUALIZE_HOME/WEB-INF/config.properties
  sed -i "s/^#virtualize.license.use_network=.*/virtualize.license.use_network=true/" $VIRTUALIZE_HOME/WEB-INF/config.properties
  sed -i "s/^#virtualize.license.network.edition=.*/virtualize.license.network.edition=custom_edition/" $VIRTUALIZE_HOME/WEB-INF/config.properties
  sed -i "s/^#virtualize.license.custom_edition_features=.*/virtualize.license.custom_edition_features=Service Enabled, Performance, Extension Pack, Validate, Message Packs, Unlimited Hits\/Day, 1 Million Hits\/Day, 500000 Hits\/Day, 100000 Hits\/Day, 50000 Hits\/Day, 25000 Hits\/Day, 10000 Hits\/Day/" $VIRTUALIZE_HOME/WEB-INF/config.properties
  sed -i "s/^#license.network.use.specified.server=.*/license.network.use.specified.server=true/" $VIRTUALIZE_HOME/WEB-INF/config.properties
  sed -i "s!^#license.network.url=.*!license.network.url=https\://localhost\:8443!" $VIRTUALIZE_HOME/WEB-INF/config.properties

  mkdir -p $VIRTUALIZE_HOME/workspace/VirtualAssets/logs/virtualize
  chown -R soavirt:parasoft $VIRTUALIZE_HOME
  echo "==============================================="
}


startTomcat() {
  echo "Startup Tomcat"
  echo "==============================================="
  if [ -f /bin/systemctl ] ; then
    systemctl start soavirt
  elif [ -f /usr/sbin/update-rc.d ] ; then
    /etc/init.d/soavirt.sh start
  else
    su - soavirt -c $CATALINA_HOME/bin/startup.sh
  fi
  echo "waiting for SOAVirt startup"
  curl --silent --location http://localhost:9080/
  echo "SOAVirt started"
  echo "==============================================="
}

#initalize download command utilities needed for SOAVirt installation
init

#install OpenJDK 17 if not installed 
installJava

#install Tomcat 10 if not installed and create SOAVirt tomcat instance
installTomcat

#download SOAVirt zip file and install in tomcat instance
installSOAVirt

#start tomcat service
#startTomcat
