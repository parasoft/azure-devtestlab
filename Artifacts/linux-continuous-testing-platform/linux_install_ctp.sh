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
curl --silent --location --remote-name http://mirror.nexcess.net/apache/tomcat/tomcat-8/v8.0.35/bin/apache-tomcat-8.0.35.tar.gz
sudo tar xvzf apache-tomcat-8.0.35.tar.gz
sudo mv apache-tomcat-8.0.35 /opt/tomcat
echo "tomcat 8 environment setup"
export CATALINA_HOME=/opt/tomcat
$CATALINA_HOME/bin/startup.sh
sudo cp tomcat.sh /etc/init.d/
sudo chmod 755 /etc/init.d/tomcat.sh
sudo update-rc.d tomcat.sh defaults
echo "cleanup"
sudo rm apache-tomcat-8.0.35.tar.gz
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
#cp ctp_dist/pstsec.war $CATALINA_HOME/webapps/
#cp ctp_dist/licenseserver.war $CATALINA_HOME/webapps/
#cp ctp_dist/em.war $CATALINA_HOME/webapps/

echo "Remove temporary installation files"
rm -rf ctp_dist
rm parasoft_environment_manager_2.7.5.zip
