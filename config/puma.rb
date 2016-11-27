#!/usr/bin/env puma

root = File.dirname(__FILE__) + '/../'

directory root
rackup root + 'config.ru'
environment 'production'
bind 'tcp://0.0.0.0:8080'
pidfile root + 'tmp/pids/server.pid'
unless ENV['DOCKERIZED']
  stdout_redirect root + 'log/puma.log', root + 'log/puma.err.log', true
  daemonize
end
threads 8, 32
workers 3
