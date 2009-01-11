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

# TODO:
# -dedicated server on garden for 'ready!' rows where rows go write their PID

module Toolshed
  require 'ftools'
  require 'socket'
  SOCKET_ROOT = '/tmp/abundance/'
  Dir.mkdir(SOCKET_ROOT) unless File.exist?(SOCKET_ROOT)
        
  # The Toolshed::block_size= method sets the UDP block size for socket operations.
  def Toolshed::block_size=(block_size)
    @@block_size = block_size
  end
  
  # The +assign_sockets+ method assign a value client and server variables
  
  def set_my_socket_as_a(role,garden_pid=Process.pid)
    case role
    when :garden
      set_my_socket
    else
      set_garden_path(garden_pid)
      set_my_socket
    end
  end
  
  def my_socket_path
    @my_socket_path
  end
  
  # 
  
  def socket_send(command,data,server_socket_path=@garden_path)
    send_block(command,data,server_socket_path)
  end
  
  def socket_duplex(command,data,server_socket_path=@garden_path)
    send_block(command,data,server_socket_path)
    Marshal.load(recv_whole_block)
  end
    
  def socket_recv
    Marshal.load(recv_whole_block)
  end
    
  private 
  
  def socket_path(pid)
    File.catname(pid.to_s,SOCKET_ROOT)
  end
  
  def set_my_socket
    @my_socket_path = socket_path(Process.pid)
    File.delete(@my_socket_path) if File.exist?(@my_socket_path)
    @my_socket = UNIXServer.open(@my_socket_path)
  end
  
  def set_garden_path(garden_pid)
    @garden_path = socket_path(garden_pid)
  end
  
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
  
  def send_block(command,data,server_socket_path)
    begin
      client = UNIXSocket.open(server_socket_path)
      client.send(Marshal.dump([command,data,@my_socket_path]),0)
      client.close
    rescue Errno::EADDRINUSE
      retry
    rescue Errno::ECONNREFUSED
      retry
    end
  end
      
end