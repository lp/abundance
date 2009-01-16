# This module provides a toolkit of helper methods to Abundance
# 
# It uses the Socket Ruby standard library to provide a communication mechanism
# between Abundance concurent processes.  It's used as both a namespace for init variables of 
# the different Abundance Classes, using Toolshed's Class Method like qualified names,
# and as mixins methods which access directly the instance variables of the client classes .
# 
# Author:: lp (mailto:lp@spiralix.org)
# Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
# 
# :title:Toolshed

module Toolshed
  require 'ftools'
  require 'socket'
  SOCKET_ROOT = '/tmp/abundance/'
  Dir.mkdir(SOCKET_ROOT) unless File.exist?(SOCKET_ROOT)
        
  # The Toolshed::block_size= method sets the Socket block size for UNIXSocket operations.
  # === Parameters
  # * _block_size_ = the block size in bytes
  def Toolshed::block_size=(block_size)
    @@block_size = block_size
  end
  
  # The +set_my_socket_as_a+ method sets a UNIXServer socket as an instance variable for the calling object in a role based fashion.
  # When the specified role is not a :garden, the Garden's socket path is also stored as an instance variable for the calling object.
  # === Parameters
  # * _role_ = the role for which you wish to establish the socket
  # * _garden_pid_ = the garden pid that will become the basename for the garden socket.  No need to specify this argument when _role_ is :garden.
  def set_my_socket_as_a(role,garden_pid=Process.pid)
    case role
    when :garden
      set_my_socket(Process.pid.to_s)
    when :gardener
      set_garden_path(garden_pid)
      set_my_socket(Process.pid.to_s + Time.now.to_i.to_s + rand(10000).to_s)
    else
      set_garden_path(garden_pid)
      set_my_socket(Process.pid.to_s)
    end
  end
  
  # The +my_socket_path+ method act as an attribute reader for the @my_socket_path instance variable of the calling object.
  def my_socket_path
    @my_socket_path
  end
  
  # The +socket_send+ method open a UNIXSocket and send packets to a UNIXServer socket.
  # When the _server_socket_path_ is not specified, it defaults sending to the Garden UNIXServer.
  # === Parameters
  # * _command_ = command part of the sent packet
  # * _data_ = data part of the sent packet
  # * _server_socket_path_ = a UNIXServer socket path for the packets to be sent to
  def socket_send(command,option,data,server_socket_path=@garden_path)
    send_block([command,option,data,server_socket_path])
  end
  
  # The +socket_duplex+ method open a UNIXSocket and send packets to a UNIXServer socket, then wait for loopback communication from destination and return results like +socket_recv+.
  # === Parameters
  # * _command_ = command part of the sent packet
  # * _data_ = data part of the sent packet
  # * _server_socket_path_ = a UNIXServer socket path for the packets to be sent to
  def socket_duplex(command,option,data,server_socket_path=@garden_path)
    send_block([command,option,data,server_socket_path])
    Marshal.load(recv_whole_block)
  end
  
  # The +socket_recv+ method calls _accept_ on a UNIXServer socket, receives all the packets from a UNIXSocket sender, join the packets back as the original block message.
  def socket_recv
    Marshal.load(recv_whole_block)
  end
    
  private 
  
  # The +socket_path+ method takes a _socket_name_ as argument and returns the absolute path to this socket.
  # === Parameters
  # * _socket_name_ = the socket file name
  def socket_path(socket_name)
    File.catname(socket_name,SOCKET_ROOT)
  end
  
  # The +set_my_socket+ method stores a UNIXServer socket inside @my_socket instance variable and also stores this socket path inside @my_socket_path.
  # === Parameters
  # * _socket_name_ = the socket file name
  def set_my_socket(socket_name)
    @my_socket_path = socket_path(socket_name)
    File.delete(@my_socket_path) if File.exist?(@my_socket_path)
    @my_socket = UNIXServer.open(@my_socket_path)
  end
  
  # The +set_garden_path+ method stores the Garden's UNIXServer socket path inside @garden_path.
  # === Parameters
  # * _garden_pid_ = the Garden process pid
  def set_garden_path(garden_pid)
    @garden_path = socket_path(garden_pid.to_s)
  end
  
  # The +recv_whole_block+ method loops receiving a sent block as packets, rebuilding the whole block and joining it.
  def recv_whole_block
    begin
      client = @my_socket.accept; block = []
      catch :whole_block do
        loop do
          packet = client.recvfrom(@@block_size)[0]
          if packet == ''
            throw :whole_block
          else
            block << packet
          end
        end
      end
      return block.join
    rescue Errno::EADDRINUSE
      retry
    end
  end
  
  # The +send_block+ method sends a block to a server socket.
  # === Parameters
  # * _command_ = command part of the sent packet
  # * _data_ = data part of the sent packet
  # * _server_socket_path_ = the UNIXServer socket path to send to 
  def send_block(message_block)
    begin
      client = UNIXSocket.open(message_block[3])
      client.send(Marshal.dump(message_block[0..2] + [@my_socket_path]),0)
      client.close
    rescue Errno::EADDRINUSE
      retry
    rescue Errno::ECONNREFUSED
      retry
    end
  end
      
end