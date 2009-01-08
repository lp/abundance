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
  require 'socket'
  UDP_HOST = 'localhost'
  @@start_port = 50000
  @@sessions = []
  
  # The Toolshed.available_port method scans for a an available UDP port and returns its value.
  def Toolshed.available_port
    port = @@start_port + 1
    catch :scan_port do
      stat = `netstat`
      loop do
        throw :scan_port unless stat =~ /localhost\.#{port}/
        port += 1
      end
    end
    @@start_port = port
    return port
  end
  
  # The Toolshed.socket_client_perm method creates a client socket permanently connected to the main server socket.  Returns the client socket object.
  def Toolshed.socket_client_perm
    socket = UDPSocket.new
    socket.connect(UDP_HOST,@@garden_port)
    return socket
  end
  
  # The Toolshed.socket_client_temp method creates a client socket available for changing connections to multiple socket servers. Returns the client socket object.
  def Toolshed.socket_client_temp
    UDPSocket.new
  end
  
  # The Toolshed.socket_server method creates a permanent main server socket.  Returns the server socket object.
  def Toolshed.socket_server(port)
    socket_server = UDPSocket.new
    socket_server.bind(nil,port)
    return socket_server
  end
  
  # The Toolshed::block_size= method sets the UDP block size for socket operations.
  def Toolshed::block_size=(block_size)
    @@block_size = block_size
  end
  
  # The Toolshed::block_size method gets and returns the UDP block size for socket operations.
  def Toolshed::block_size
    @@block_size
  end
  
  # The Toolshed::garden_port= sets the UDP socket port for the garden server.
  def Toolshed::garden_port=(garden_port)
    @@garden_port = garden_port
  end
  
  # The Toolshed::garden_port gets the UDP socket port of the garden server.
  def Toolshed::garden_port
    @@garden_port
  end
  
  # The +socket_client_perm_duplex+ method is used as the main Row loop send/receive method and for all gardener's send/receive
  def socket_client_perm_duplex(command,data)
    block_splitter([command,data]) do |block|
      @socket_client_perm.send(block,0)
    end
    recv_block,address = block_filter { @socket_client_perm.recvfrom(@@block_size) }
    return Marshal.load(recv_block)
  end
  
  def socket_client_perm_send(command,data)
    block_splitter([command,data]) do |block|
      @socket_client_perm.send(block,0)
    end
  end
  
  # The +socket_client_temp+ method is used by the Garden for connecting with the Row idle socket for quick messages. 
  def socket_client_temp(command,data,port)
    @socket_client_temp.connect(UDP_HOST,port)
    block_splitter([command,data]) do |block|
      @socket_client_temp.send(block,0)
    end
  end
  
  # The +socket_server_recv+ method is used by the Garden permanent socket and by the Row idle socket to wait for incomming messages.
  def socket_server_recv
    block,address = block_filter { @socket_server.recvfrom(@@block_size) }
    clientport = address[1]; clientname = address[2]; clientaddr = address[3] 
    command, data = Marshal.load(block)
    return command, data, clientport, clientname, clientaddr
  end
  
  # The +socket_server_send+ method is used by the Garden to answer back to socket clients.
  def socket_server_send(command,data,clientaddr,clientport)
    block_splitter([command,data]) do |block|
      @socket_server.send(block, 0, clientaddr, clientport)
    end
  end
  
  private 
  # The +block_splitter+ method is used internally by the Toolshed method to split message into acceptable UDP block size.  Its operating as a block method, sending a message chunk on each iteration.
  def block_splitter(data)
    data_string = Marshal.dump(data)
    if data_string.size >= @@block_size
      parts = data_string.size / (@@block_size - @@block_size/32) + 1
      yield Marshal.dump([:block_head,Process.pid,parts])
      parts.times do |num|
        part = [data_string[0,@@block_size - @@block_size/32]]; data_string[0,@@block_size - @@block_size/32] = ''
        yield Marshal.dump([:block_part,Process.pid,num, part])
      end
    else
      yield data_string
    end
  end
  
  # The +block_filter+ method is used internally by the Toolshed method to filter splitted messages blocks, buffering them until the full message can be reconstructed.
  def block_filter
    loop do
      block,address = yield
      block_array = Marshal.load(block)
      if block_array[0] == :block_head
        @@sessions[block_array[1]] = {} if @@sessions[block_array[1]].nil?
        @@sessions[block_array[1]][:size] = block_array[2]
        @@sessions[block_array[1]][:address] = address
      elsif block_array[0] == :block_part
        @@sessions[block_array[1]] = {} if @@sessions[block_array[1]].nil?
        @@sessions[block_array[1]][:data] = [] if @@sessions[block_array[1]][:data].nil?
        @@sessions[block_array[1]][:data][block_array[2]] = block_array[3]
      else
        return block,address
      end
      if ! @@sessions[block_array[1]].nil? && ! @@sessions[block_array[1]][:data].nil? && @@sessions[block_array[1]][:data].size == @@sessions[block_array[1]][:size]
        block = @@sessions[block_array[1]][:data].join
        address = @@sessions[block_array[1]][:address]
        @@sessions[block_array[1]] = nil
        return block,address
      end
    end
  end
  
end