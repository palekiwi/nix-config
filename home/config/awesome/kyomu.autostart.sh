#!/usr/bin/env bash

function run {
  if ! pgrep $1;
  then
    $@&
  fi
}

run sxhkd

run nextcloud
run slack

xmodmap ~/.Xmodmap
