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
  
  # The +new+ class method initializes the class.
  # As part of the Abundance lib, Gardener is not initialized directly, 
  # but rather through +Abundance.gardener+.
  # === Parameters
  # * _:seed_size_ = allowed seed size in bytes
  # * _:rows_ = garden rows number, the number of concurent threads
  # * _:init_timeout_ = allow to pause execution to allow for larger gardens to initialize
  # === Example
  #  gardener = Gardener.new({:seed_size => 1024, :rows => 6, :init_timeout}) { your_special_garden function }
  # 
  
  def initialize(options,gardener_block)
    Toolshed::block_size = options[:seed_size]
    Toolshed::garden_port = Toolshed.available_port
    
    @garden = Garden.new
    @garden_rows = @garden.rows(options[:rows], options[:init_timeout], gardener_block)
    
    @socket_client_perm = Toolshed.socket_client_perm
  end
  
  # The +seed+ method for the Gardener instance allow to sow a command in the Gardener's Garden.
  # === Parameter
  # * _command_ = a ruby expression or object
  # === Example
  #  id_seed_1 = gardener.seed(system 'ruby -v')
  
  def seed(command)
    command, data = socket_client_perm_duplex(:seed,command)
    return data
  end
  
  # The +growth+ method for the Gardener instance allow to get report of the growing process
  # === Parameter
  # The parameter given as a symbol specifies the level of growth report you wish to get:
  # * _:progress_ = return actual progress status, scaled between 0.00 and 1.00
  # * _:seed_ = return total seeds waiting to be processed
  # * _:sprout_ = return total seeds actually in process
  # * _:crop_ = return total seeds for which process has completed
  # === Example
  #  progress = gardener.growth(:progress)
  #  puts "progress is now #{progress}"  # => progress is now 0.75
  
  def growth(crop=:progress)
    command, data = socket_client_perm_duplex(:growth,crop)
    return data
  end
  
  # The +harvest+ method for the Gardener instance allow to get arrays of results for each queue level
  # === Parameter
  # The parameter given as a symbol specifies the level of queue results you wish to get:
  # * _seedID_ = return the result for a specific seed, if seed hasn't processed it wait until completed
  # * _:crop_ = return an array of seed for which process has completed
  # * _:sprout_ = return an array of seed actually processing
  # * _:seed_ = return an array of seed waiting to be processed
  # * _:all_ = return a hash of respective arrays for crops, sprouts and seeds
  # === Example
  #  seed1_result = gardener.harvest(id_seed_1)
  
  def harvest(crop)
    command, data = socket_client_perm_duplex(:harvest,crop)
    return data
  end
  
  # The +close+ method for the Gardener instance allow to safely close the Garden and its Rows.
  # It return a hash of respective arrays for crops, sprouts and seeds at the moment of closing.
  # === Example
  #  final_harvest = gardener.close
  
  def close
    command, data = socket_client_perm_duplex(:close,{:level => :garden, :pid => @garden_rows.pids})
    return data
  end
  
end