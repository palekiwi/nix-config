#!/usr/bin/env bash

function run {
  if ! pgrep $1;
  then
    $@&
  fi
}

function run_flatpak {
  if ! flatpak ps | grep $1;
  then
    flatpak run $@&
  fi
}

function run_app {
  if ! pgrep $1;
  then
    ~/apps/$@&
  fi
}

run picom -b --config $HOME/.config/picom/picom.conf
run sxhkd
run ibus-daemon -drxR
run unclutter --timeout 1 --start-hidden --ignore-scrolling

run slack
run nextcloud

xmodmap ~/.Xmodmap

run xscreensaver -no-splash
