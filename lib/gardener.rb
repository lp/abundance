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
  # * :wheelbarrow = the socket size for the garden communication packets, in bytes, up to 8192, defaults to 124
  # * :rows = garden rows number, the number of concurent threads
  # * :init_timeout = allow to pause execution to allow for larger gardens to initialize
  # === Example
  #  gardener = Gardener.new({:wheelbarrow => 124, :rows => 6, :init_timeout}) { your_special_garden function }
  # 
  
  def initialize(options,gardener_block)
    Toolshed::block_size = if options[:wheelbarrow].nil? then 124
                          elsif options[:wheelbarrow] > 8192 then 8192
                          else options[:wheelbarrow]
                          end
    
    @garden = Garden.new
    @garden_rows = @garden.rows(options[:rows], options[:init_timeout], gardener_block)
    
    set_my_socket_as_a(:gardener,@garden.pid)
  end

	def garden_pid
		@garden.pid
	end
	
	def rows_pids
  	@garden_rows.pids
	end
  # The +init_status+ method for the Gardener instance allow to harvest an initialisation status message
  # that would have been set by the Abundance.init_status method, inside the Abundance.gardener's block. 
  # It returns an array of hash, one hash for each garden rows.
  # === Example
  #   puts gardener.init_status.inspect   # => [{:message=>"init ok", :success=>true, :pid=>4760}, {:message=>"init failed", :success=>false, :pid=>4761}] 
  def init_status
    message_block = socket_duplex([:harvest,:init,@garden_rows.pids.size,@garden_path])
    message_block[2].map! do |row|
      {:success => row[:success], :message => row[:message], :pid => row[:id]}
    end
    return message_block[2]
  end
  
  # The +seed+ method for the Gardener instance allow to sow a command in the Gardener's Garden.
  # === Parameter
  # * _data_ = a ruby expression or object
  # === Example
  #  id_seed_1 = gardener.seed("system 'ruby -v'")
  
  def seed(data)
    message_block = socket_duplex([:seed,:one,data,@garden_path])
    return message_block[2]
  end
  
  # The +seed_all+ method allow to send a command to all row processes, usefull for a parameter change
  # that needs to affect the prefered behaviour of all row.  It returns an array containing hashes for each rows results.
  # === Parameter
  # * _data_ = a ruby expression or object
  # === Example
  #   result = gardener.seed_all("pref local")  # =>  [{:success=>true, :message=>["row pref changed to local"], :seed=>"pref local", :pid=>14915},
  #                                               {:success=>true, :message=>["row pref changed to local"], :seed=>"pref local", :pid=>14913}]
  def seed_all(data)
    message_block = socket_duplex([:seed,@garden_rows.pids.size,data,@garden_path])
    message_block[2].map! do |row|
      {:success => row[:success], :message => row[:message], :pid => row[:id]}
    end
    return message_block[2]
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
  
  def growth(option=:progress)
    message_block = socket_duplex([:growth,option,nil,@garden_path])
    return message_block[2]
  end
  
  # The +harvest+ method for the Gardener instance allow to get arrays of results for each queue level.
  # It has two different behaviour on queue data, one for ripe elements where it removes them from crop array ( on _seedID_ and :crop invocations ),
  # for all other methods of invocation it leaves the queue intact.
  # === Parameter
  # The option given as a symbol specifies the level of queue results you wish to get:
  # * :crop = return an array of seed for which process has completed, empties the crop array.
  # * :sprout = return an array of seed actually processing
  # * :seed = return an array of seed waiting to be processed
  # * :all = return a hash of respective arrays for crops, sprouts and seeds
  # * :full_crop = wait for all seeds to be done processing, then returns as in :crop.
  # * :one = return the result for a specific seed, if seed hasn't processed it wait until completed, _seed_id_ is removed from crop array
  # When specifying :one as option, a seed ID is also required:
  # * _seedID_ = the id as returned by the +seed+ method
  # === Example
  #  seed1_result = gardener.harvest(:one,id_seed_1)
  
  def harvest(option,seed_id=nil)
    message_block = socket_duplex([:harvest,option,seed_id,@garden_path])
    return message_block[2]
  end
  
  # The +close+ method for the Gardener instance allow to safely close the Garden and its Rows.
  # It return a hash of respective arrays for crops, sprouts and seeds at the moment of closing.
  # === Example
  #  final_harvest = gardener.close
  
  def close
    message_block = socket_duplex([:close,:garden,@garden_rows.pids,@garden_path])
    return message_block[2]
  end
  
end