#!/bin/bash

set -e

if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"

    apt-get -y update

    apt-get -y install default-jdk
    apt-get -y install tomcat8

elif [ -f /usr/bin/yum ] ; then 
    echo "Using YUM package manager"

    yum -y update
    yum clean all

    yum install -y default-jdk
    yum install -y tomcat8
fi