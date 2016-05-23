#!/bin/bash
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

echo "export JAVA_HOME=/usr/oraclejdk/jdk1.8.0_92/bin" > /etc/profile.d/java.sh

if type -p java; then
   version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
   echo $version
fi

if [[ "$version" = "1.8.0_92"  ]]; then
   echo "Oracle JDK installation complete"
else 
   echo "Oracle JDK installation failed" 
fi

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
#cp ctp_dist/pstsec.war $CATALINA_HOME/webapps/
#cp ctp_dist/licenseserver.war $CATALINA_HOME/webapps/
#cp ctp_dist/em.war $CATALINA_HOME/webapps/

echo "Remove temporary installation files"
rm -rf ctp_dist
rm parasoft_environment_manager_2.7.5.zip
