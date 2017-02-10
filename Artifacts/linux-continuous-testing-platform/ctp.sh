#!/bin/bash
#
### BEGIN INIT INFO
# Provides:          ctp
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remore_fs $syslog
# Default-Start:     2 3 5
# Default-Stop:      2 3 5
# Short-Description: Apache Tomcat 8
# Description:       start web server
### END INIT INFO
#
# description: Apache Tomcat init script for Parasoft CTP
# processname: ctp
# chkconfig: 234 20 80
#
#
# Copyright (C) 2014 Miglen Evlogiev
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Initially forked from: gist.github.com/valotas/1000094
# Source: gist.github.com/miglen/5590986


#Location of JAVA_HOME (bin files)
export JAVA_HOME=/usr/oraclejdk/jdk1.8.0_121

#Add Java binary files to PATH
export PATH=$JAVA_HOME/bin:$PATH

#CATALINA_HOME is the location of the bin files of Tomcat
export CATALINA_HOME=/usr/local/tomcat

#CATALINA_BASE is the location of the tomcat instance configuration
export CATALINA_BASE=/var/tomcat/ctp

#CATALINA_OPTS are the Java VM arguments used when starting Tomcat
export CATALINA_OPTS="-server -XX:+UseParallelGC"

#JAVA_OPTS are the Java VM arguments used when both starting and shutting down Tomcat
export JAVA_OPTS="-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"

#TOMCAT_USER is the default user of tomcat
export TOMCAT_USER=ctp

#TOMCAT_USAGE is the message if this script is called without any options
TOMCAT_USAGE="Usage: $0 {\e[00;32mstart\e[00m|\e[00;31mstop\e[00m|\e[00;31mkill\e[00m|\e[00;32mstatus\e[00m|\e[00;31mrestart\e[00m}"

#SHUTDOWN_WAIT is wait time in seconds for java proccess to stop
SHUTDOWN_WAIT=20
 
tomcat_pid() {
        echo `ps -fe | grep $CATALINA_BASE | grep -v grep | tr -s " "|cut -d" " -f2`
}
 
start() {
  pid=$(tomcat_pid)
  if [ -n "$pid" ]
  then
    echo -e "\e[00;31mTomcat is already running (pid: $pid)\e[00m"
  else
    # Start tomcat
    echo -e "\e[00;32mStarting tomcat\e[00m"
    totalk=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
    if [ "$totalk" -gt "8388608" ]
    then
      JAVA_HEAP="-Xms1536M -Xmx1536M"
    elif [ "$totalk" -gt "4194304" ]
    then
      JAVA_HEAP="-Xms1024M -Xmx1024M"
    elif [ "$totalk" -gt "2097152" ]
    then
      JAVA_HEAP="-Xms768M -Xmx768M"
    elif [ "$totalk" -gt "1048576" ]
    then
      JAVA_HEAP="-Xms384M -Xmx384M -Xss512K"
    elif [ "$totalk" -gt "524288" ]
    then
      rm $CATALINA_BASE/webapps/parabank.war
      JAVA_HEAP="-Xms256M -Xmx256M -Xss256K"
    else
      rm $CATALINA_BASE/webapps/parabank.war
      rm $CATALINA_BASE/webapps/pstsec.war
      JAVA_HEAP="-Xms144M -Xmx144M -Xss228K"
    fi
    export CATALINA_OPTS="$CATALINA_OPTS $JAVA_HEAP"
    #ulimit -n 100000
    #umask 007
    #/bin/su -p -s /bin/sh $TOMCAT_USER
        if [ `user_exists $TOMCAT_USER` = "1" ]
        then
            /bin/su $TOMCAT_USER -s /bin/sh -c "cd $CATALINA_BASE; $CATALINA_HOME/bin/startup.sh"
        else
            echo -e "\e[00;31mTomcat user $TOMCAT_USER does not exists. Starting with $(id)\e[00m"
            sh $CATALINA_HOME/bin/startup.sh
        fi
        DELAY=1
        until curl -f --silent -o - "http://localhost:8080/em/healthcheck" > /dev/null
        do
            if [[ "$DELAY" -gt "60" ]]; then
                echo -e "\e[00;31mTomcat did not finish webapp startup after $DELAY seconds\e[00m"
                return 1
            fi
            echo -e "\e[00;31mwaiting for CTP webapp startup\e[00m"
            sleep ${DELAY}s
            DELAY=$((DELAY * 2))
        done
        status
  fi
  return 0
}
 
status(){
          pid=$(tomcat_pid)
          if [ -n "$pid" ]
            then echo -e "\e[00;32mTomcat is running with pid: $pid\e[00m"
          else
            echo -e "\e[00;31mTomcat is not running\e[00m"
            return 3
          fi
}

terminate() {
	echo -e "\e[00;31mTerminating Tomcat\e[00m"
	kill -9 $(tomcat_pid)
}

stop() {
  pid=$(tomcat_pid)
  if [ -n "$pid" ]
  then
    echo -e "\e[00;31mStoping Tomcat\e[00m"
    #/bin/su -p -s /bin/sh $TOMCAT_USER
        sh $CATALINA_HOME/bin/shutdown.sh
 
    let kwait=$SHUTDOWN_WAIT
    count=0;
    until [ `ps -p $pid | grep -c $pid` = '0' ] || [ $count -gt $kwait ]
    do
      echo -n -e "\n\e[00;31mwaiting for processes to exit\e[00m";
      sleep 1
      let count=$count+1;
    done
 
    if [ $count -gt $kwait ]; then
      echo -n -e "\n\e[00;31mkilling processes didn't stop after $SHUTDOWN_WAIT seconds\e[00m"
      terminate
    fi
  else
    echo -e "\e[00;31mTomcat is not running\e[00m"
  fi
 
  return 0
}
 
user_exists(){
        if id -u $1 >/dev/null 2>&1; then
        echo "1"
        else
                echo "0"
        fi
}
 
case $1 in
	start)
	  start
	;;
	stop)  
	  stop
	;;
	restart)
	  stop
	  start
	;;
	status)
		status
		exit $?
	;;
	kill)
		terminate
	;;
	*)
		echo -e $TOMCAT_USAGE
	;;
esac
exit 0