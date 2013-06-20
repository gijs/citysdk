#!/usr/local/bin/ruby

require 'json'

dbconf = JSON.parse(File.read('../database.json'))

database = "postgres://#{dbconf['user']}:#{dbconf['password']}@#{dbconf['host']}/#{dbconf['database']}"
command = "sequel -m migrations #{database}"

system command