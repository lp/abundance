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
  
  # main Row loop send receive
  # and gardener all send receive
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
  
  # Garden to Rows, quick message
  def socket_client_temp(command,data,port)
    @socket_client_temp.connect(UDP_HOST,port)
    block_splitter([command,data]) do |block|
      @socket_client_temp.send(block,0)
    end
  end
  
  # Garden main receive
  # and Rows Idle receive
  def socket_server_recv
    block,address = block_filter { @socket_server.recvfrom(@@block_size) }
    clientport = address[1]; clientname = address[2]; clientaddr = address[3] 
    command, data = Marshal.load(block)
    return command, data, clientport, clientname, clientaddr
  end
  
  # Garden main send
  def socket_server_send(command,data,clientaddr,clientport)
    block_splitter([command,data]) do |block|
      @socket_server.send(block, 0, clientaddr, clientport)
    end
  end
  
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