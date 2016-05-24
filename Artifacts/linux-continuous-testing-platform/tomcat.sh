#!/bin/bash
# Tomcat auto-start

if [ "$JAVA_HOME" = "" ]; then
	export JAVA_HOME=/usr/oraclejdk/jdk1.8.0_92
fi
export CATALINA_HOME=/opt/tomcat

case $1 in
start)
sh //opt/tomcat/bin/startup.sh
;;
stop) 
sh /opt/tomcat/bin/shutdown.sh
;;
restart)
sh /opt/tomcat/bin/shutdown.sh
sh /opt/tomcat/bin/startup.sh
;;
esac 
exit 0