#!/usr/bin/env ruby
require 'socket'

server = TCPServer.new 1991 # Server bound to port 2000

loop do
  client = server.accept    # Wait for a client to connect
  client.puts "Hello !"
  client.puts "Time is #{Time.now}"
  client.close
end
