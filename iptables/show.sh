#!/bin/sh -x
iptables -L -v -n
iptables -t nat -L -v -n
