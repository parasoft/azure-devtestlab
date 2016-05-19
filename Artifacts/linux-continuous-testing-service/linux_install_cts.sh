#!/bin/bash

set -e

if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"

    apt-get -y update

    apt-get -y install tomcat

elif [ -f /usr/bin/yum ] ; then 
    echo "Using YUM package manager"

    yum -y update
    yum clean all

    yum install -y tomcat
fi