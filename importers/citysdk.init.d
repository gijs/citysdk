#!/bin/bash

PROG[0]="kv8daemon"
PROG[1]="divvdaemon"

PROG_PATH="/var/www/citysdk/shared/daemons"
LOG_PATH="/var/www/citysdk/shared/log"
PID_PATH="/var/www/citysdk/shared/pids"

. /usr/local/rvm/scripts/rvm

start() {
    if [ -e "$PID_PATH/${PROG[0]}.pid" ]; then
        ## Program is running, exit with error.
        echo "Error! citysdk is currently running!" 1>&2
        exit 1
    else
        $PROG_PATH/${PROG[0]} --daemon --pid "$PID_PATH/${PROG[0]}.pid" --log "$LOG_PATH/${PROG[0]}.log"
        $PROG_PATH/${PROG[1]} --daemon --pid "$PID_PATH/${PROG[1]}.pid" --log "$LOG_PATH/${PROG[1]}.log"
    fi
}

stop() {
    if [ -e "$PID_PATH/${PROG[0]}.pid" ]; then
        $PROG_PATH/${PROG[0]} --kill --pid "$PID_PATH/${PROG[0]}.pid" 
        $PROG_PATH/${PROG[1]} --kill --pid "$PID_PATH/${PROG[1]}.pid" 
    else
        ## Program is not running, exit with error.
        echo "Error! citysdk not started!" 1>&2
        exit 1
    fi
}

status() {
    if [ -e "$PID_PATH/${PROG[0]}.pid" ]; then
        echo "citysdk is running."
    else
      echo "citysdk is not running."
    fi
}


if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

case "$1" in
    start)
        start
        exit 0
    ;;
    stop)
        stop
        exit 0
    ;;
    status)
        status
        exit 0
    ;;
    reload|restart|force-reload)
        stop
        start
        exit 0
    ;;
    **)
        echo "Usage: $0 {start|stop|status|reload}" 1>&2
        exit 1
    ;;
esac

