# This class provides the gardener part of the Gardener,Garden,Seed natural design patern
# 
# The Gardener act as the client class for accessing and assessing the Garden ressources.
# Its initialization occurs through the +Abundance.gardener+ class method.
# Its instance methods are fourthfold, following the 4 states of the garden.
# Like the 4 seasons northern hemisphere gardening cycles:
# * seed = the setting of your command cycle
# * grownth = the evolution of your command growing period
# * harvest = the getting of your command results
# * close = the closing and dying cycle
# 
# Author:: lp (mailto:lp@spiralix.org)
# Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
# 
# :title:Gardener

class Gardener
  require 'lib/toolshed'
  include Toolshed
  
  def initialize(options,gardener_block)
    Toolshed::block_size = options[:seed_size]
    Toolshed::garden_port = Toolshed.available_port
    
    @garden = Garden.new
    @garden_rows = @garden.rows(options[:rows], options[:init_timeout], gardener_block)
    
    @socket_client_perm = Toolshed.socket_client_perm
  end
  
  def seed(command)
    command, data = socket_client_perm_duplex(:seed,command)
    return data
  end
  
  def growth(crop=:progress)
    command, data = socket_client_perm_duplex(:growth,crop)
    return data
  end
  
  def harvest(crop)
    command, data = socket_client_perm_duplex(:harvest,crop)
    return data
  end
  
  def close
    command, data = socket_client_perm_duplex(:close,{:level => :garden, :pid => @garden_rows.pids})
    return data
  end
  
end