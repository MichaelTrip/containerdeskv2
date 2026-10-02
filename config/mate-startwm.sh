#!/bin/sh
if [ -r /etc/profile ]; then
    . /etc/profile
fi
if [ -r "$HOME/.profile" ]; then
    . "$HOME/.profile"
fi
exec /usr/local/bin/mate-session-supervisor
