# This module provides a toolkit of helper methods to Abundance
# 
# Author:: lp (mailto:lp@spiralix.org)
# Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
# 
# :title:Toolshed

module Toolshed
  require 'socket'
  UDP_HOST = 'localhost'
  @@start_port = 50000
  
  def Toolshed.available_port
    port = @@start_port + 1
    catch :scan_port do
      loop do
        begin
          socket = UDPSocket.new
          socket.connect(UDP_HOST,port)
          socket.send('',0)
          response,address = socket.recvfrom(1024)
        rescue Errno::ECONNREFUSED
          throw :scan_port
        end
        port += 1
      end
    end
    @@start_port = port
    return port
  end
  
  def Toolshed.socket_client_perm
    socket = UDPSocket.new
    socket.connect(UDP_HOST,@@garden_port)
    return socket
  end
  
  def Toolshed.socket_client_temp
    UDPSocket.new
  end
  
  def Toolshed.socket_server(port)
    socket_server = UDPSocket.new
    socket_server.bind(nil,port)
    return socket_server
  end
  
  def Toolshed::block_size=(block_size)
    @@block_size = block_size
  end
  
  def Toolshed::block_size
    @@block_size
  end
  
  def Toolshed::garden_port=(garden_port)
    @@garden_port = garden_port
  end
  
  def Toolshed::garden_port
    @@garden_port
  end
  
  def socket_client_perm_duplex(command,data)
    @socket_client_perm.send(Marshal.dump([command,data]),0)
    recv_block,address = @socket_client_perm.recvfrom(@@block_size)
    return Marshal.load(recv_block)
  end
  
  def socket_client_perm_send(command,data)
    @socket_client_perm.send(Marshal.dump([command,data]),0)
  end
  
  def socket_client_temp(command,data,port)
    @socket_client_temp.connect(UDP_HOST,port)
    @socket_client_temp.send(Marshal.dump([command,data]),0)
  end
  
  def socket_server_recv
    block,address = @socket_server.recvfrom(@@block_size)
    clientport = address[1]; clientname = address[2]; clientaddr = address[3] 
    command, data = Marshal.load(block)
    return command, data, clientport, clientname, clientaddr
  end
  
  def socket_server_send(command,data,clientaddr,clientport)
    @socket_server.send(Marshal.dump([command,data]), 0, clientaddr, clientport)
  end
  
end