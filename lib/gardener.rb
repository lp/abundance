# This class provides the gardener part of the Gardener,Garden,Seed natural design patern
# 
# The Gardener act as the client class for accessing and assessing the Garden ressources.
# Its initialization occurs through the Abundance.gardener class method.
# 
# The Gardener's instance methods are:
# * init_status = the return message for the initialisation cycle, as set by the Abundance.init_status method.
# * seed = the setting of your command
# * growth = the evolution of your command growing period
# * harvest = the getting of your command results
# * close = wrap everything up and does a legit close
# 
# Author:: lp (mailto:lp@spiralix.org)
# Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
# 
# :title:Gardener

class Gardener
  require 'toolshed'
  include Toolshed
  
  # The +new+ class method initializes the class.
  # As part of the Abundance lib, Gardener is not initialized directly, 
  # but rather through Abundance.gardener.
  # === Parameters
  # * :wheelbarrow = the socket size for the garden communication packets, in bytes, range from 1024 to 8192, defaults to 8192
  # * :rows = garden rows number, the number of concurent threads
  # * :init_timeout = allow to pause execution to allow for larger gardens to initialize
  # === Example
  #  gardener = Gardener.new({:wheelbarrow => 1024, :rows => 6, :init_timeout}) { your_special_garden function }
  # 
  
  def initialize(options,gardener_block)
    Toolshed::block_size = if options[:wheelbarrow].nil? || options[:wheelbarrow] > 8192 then 8192
                          elsif options[:wheelbarrow] < 1024 then 1024
                          else options[:wheelbarrow]
                          end
    Toolshed::garden_port = Toolshed.available_port
    
    @garden = Garden.new
    @garden_rows = @garden.rows(options[:rows], options[:init_timeout], gardener_block)
    
    @socket_client_perm = Toolshed.socket_client_perm
  end
  
  # The +init_status+ method for the Gardener instance allow to harvest an initialisation status message
  # that would have been set by the Abundance.init_status method, inside the Abundance.gardener's block. 
  # It returns an array of hash, one hash for each garden rows.
  # === Example
  #   puts gardener.init_status.inspect   # => [{:message=>"init ok", :success=>true, :pid=>4760}, {:message=>"init failed", :success=>false, :pid=>4761}] 
  def init_status
    command, data = socket_client_perm_duplex(:init,@garden_rows.pids.size)
    data.map! do |row|
      {:success => row[:success], :message => row[:message], :pid => row[:id]}
    end
    return data
  end
  
  # The +seed+ method for the Gardener instance allow to sow a command in the Gardener's Garden.
  # === Parameter
  # * _command_ = a ruby expression or object
  # === Example
  #  id_seed_1 = gardener.seed("system 'ruby -v'")
  
  def seed(command)
    command, data = socket_client_perm_duplex(:seed,command)
    return data
  end
  
  # The +seed_all+ method allow to send a command to all row processes, usefull for a parameter change
  # that needs to affect the prefered behaviour of all row.  It returns an array containing hashes for each rows results.
  # === Parameter
  # * _command_ = a ruby expression or object
  # === Example
  #   result = gardener.seed_all("pref local")  # =>  [{:success=>true, :message=>["row pref changed to local"], :seed=>"pref local", :pid=>14915},
  #                                               {:success=>true, :message=>["row pref changed to local"], :seed=>"pref local", :pid=>14913}]
  def seed_all(command)
    seed = [@garden_rows.pids.size, command]
    command, data = socket_client_perm_duplex(:seed_all, seed)
    data.map! do |row|
      {:success => row[:success], :message => row[:message], :pid => row[:id]}
    end
    return data
  end
  
  # The +growth+ method for the Gardener instance allow to get report of the growing process
  # === Parameter
  # The parameter given as a symbol specifies the level of growth report you wish to get:
  # * :progress = return actual progress status, scaled between 0.00 and 1.00
  # * :seed = return total seeds waiting to be processed
  # * :sprout = return total seeds actually in process
  # * :crop = return total seeds for which process has completed
  # === Example
  #  progress = gardener.growth(:progress)
  #  puts "progress is now #{progress}"  # => progress is now 0.75
  
  def growth(crop=:progress)
    command, data = socket_client_perm_duplex(:growth,crop)
    return data
  end
  
  # The +harvest+ method for the Gardener instance allow to get arrays of results for each queue level.
  # It has two different behaviour on queue data, one for ripe elements where it removes them from crop array ( on _seedID_ and :crop invocations ),
  # for all other methods of invocation it leaves the queue intact.
  # === Parameter
  # The parameter given as a symbol specifies the level of queue results you wish to get:
  # * seedID = return the result for a specific seed, if seed hasn't processed it wait until completed, _seedID_ is removed from crop array
  # * :crop = return an array of seed for which process has completed, empties the crop array.
  # * :sprout = return an array of seed actually processing
  # * :seed = return an array of seed waiting to be processed
  # * :all = return a hash of respective arrays for crops, sprouts and seeds
  # * :full_crop = wait for all seeds to be done processing, then returns as in :crop.
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