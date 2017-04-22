#!/bin/bash
#
### BEGIN INIT INFO
# Provides:          datarepo
# Required-Start:    $remote_fs $syslog ctp cts
# Required-Stop:     $remore_fs $syslog ctp cts
# Default-Start:     2 3 5
# Default-Stop:      2 3 5
# Short-Description: Data Repository
# Description:       start MongoDB Data Repository server
### END INIT INFO
#
# description: MongoDB init script for Parasoft Data Repository server
# processname: datarepo
# chkconfig: 234 30 70
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

 
#Location of DATA_REPO_HOME (bin files)
export DATA_REPO_HOME=/opt/DataRepositoryServer-linux-x86_64
 
#DATA_REPO_USER is the default user of Data Repository
export DATA_REPO_USER=datarepo
 
start() {
  echo -e "\e[00;31mWaiting for CTP to start up first\e[00m"
  sleep 10
  curl -f --silent -o - "http://localhost:8080/em/healthcheck" > /dev/null
  sleep 20
  # Start Data Repository
  if [ `user_exists $DATA_REPO_USER` = "1" ]
  then
    totalk=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
    if [ "$totalk" -gt "1048576" ]
    then
          /bin/su $DATA_REPO_USER -s /bin/sh -c "$DATA_REPO_HOME/server.sh start"
    fi
  else
          echo -e "\e[00;31mData Repository user $DATA_REPO_USER does not exists. Starting with $(id)\e[00m"
          sh $DATA_REPO_HOME/server.sh start
  fi
  return 0
}
 
status(){
  sh $DATA_REPO_HOME/server.sh status
}

stop() {
  # Stop Data Repository
  if [ `user_exists $DATA_REPO_USER` = "1" ]
  then
          /bin/su $DATA_REPO_USER -s /bin/sh -c "$DATA_REPO_HOME/server.sh stop"
  else
          echo -e "\e[00;31mData Repository user $DATA_REPO_USER does not exists. Starting with $(id)\e[00m"
          sh $DATA_REPO_HOME/server.sh stop
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
		stop
	;;		
	*)
		sh $DATA_REPO_HOME/server.sh
	;;
esac    
exit 0