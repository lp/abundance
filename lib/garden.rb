# These classes provides the garden part of the Gardener,Garden,Seed natural design patern
# 
# The Garden is where the thread concurency is implemented,
# offering itself as a thread queue manager,
# dispatching seeds from the Gardener to its Rows child class and back again.
# it does so using its child class, the Rows.  Since Ruby doesn't implement Native Threads,
# and only Native Threads scales to multi-core execution, the way to implement concurent execution is
# through splitting the task at hand between multiple single threaded parallel executions.
# The Rows system does exactly that, using the Ruby fork function, then connecting the isolated running
# processes to the Garden, through a simple socket system provided by the Toolshed Module.
# 
# Author:: lp (mailto:lp@spiralix.org)
# Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
# 
# :title:Garden

class Garden
	require File.join( File.dirname( File.expand_path(__FILE__)), 'rows')
	require File.join( File.dirname( File.expand_path(__FILE__)), 'garden_cycles')
  include Cycles
	require File.join( File.dirname( File.expand_path(__FILE__)), 'toolshed')
  include Toolshed
  
  attr_reader :pid
  
  # The +new+ class method initializes the Garden.
  # As part of the Abundance lib, Garden is not initialized directly, 
  # but rather as a side effect of the Gardener's initialization.
  # Its instance resides in the @garden Gardener's instance variable.
  # Its real muscles are inaccessibles from instance method intervention,
  # because of its nature as a forked Ruby process.
  # === Example
  #  garden = Garden.new
  
  def initialize
    @pid = fork do
      set_my_containers
      set_my_socket_as_a(:garden)
      
      loop do
				route_message_blocks
				seed_available_rows
				$log_abundance.debug('garden') {"select reader: #{@reader[:sockets].inspect} writer: #{@writer[:sockets]}"}
        ready = select(@reader[:sockets],@writer[:sockets],nil,10)
        unless ready.nil?
          readable, writable = ready[0..1]

          crop_writable(writable) if writable
          sprout_readable(readable) if readable
        end
      end
    end
  end

end