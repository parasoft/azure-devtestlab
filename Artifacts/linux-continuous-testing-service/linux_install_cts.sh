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

echo "Download CTS distribution"
curl --silent --location --remote-name http://parasoft.westus.cloudapp.azure.com/builds/parasoft_continuous_testing_service_9.9.5.war

echo "Extract CTS webapp"
VIRTUALIZE_HOME=/usr/local/parasoft/virtualize
mkdir -p $VIRTUALIZE_HOME
mv parasoft_continuous_testing_service_9.9.5.war $VIRTUALIZE_HOME
cd $VIRTUALIZE_HOME
$JAVA_HOME/bin/jar -xf parasoft_continuous_testing_service_9.9.5.war
rm parasoft_continuous_testing_service_9.9.5.war

echo "Configure Tomcat to deploy CTS webapp"
#echo "<Context docBase=\"$VIRTUALIZE_HOME\" path=\"\" reloadable=\"true\" />" > $CATALINA_HOME/conf/Catalina/localhost/ROOT.xml
#sed -i 's/8080/9080/g' $VIRTUALIZE_HOME/WEB-INF/config.properties \
#sed -i 's/8443/9443/g' $VIRTUALIZE_HOME/WEB-INF/config.properties \
#sed -i 's/8080/9080/g' $CATALINA_HOME/conf/server.xml \
#sed -i 's/8443/9443/g' $CATALINA_HOME/conf/server.xml \
#sed -i 's/8009/0/g' $CATALINA_HOME/conf/server.xml
