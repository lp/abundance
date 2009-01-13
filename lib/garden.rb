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
  require 'garden_rows'
  require 'garden_cycles'
  include Cycles
  require 'toolshed'
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
        seed_if_row_available
        
        command, data, client_socket_path = socket_recv
        case command
        when :seed
          place_seed_in_queue(command,data,client_socket_path)
        when :row
          this_row_is_available(command,data,client_socket_path)  
        when :crop
          save_crop_for(command,data,client_socket_path)
        when :growth
          report_growth(command,data,client_socket_path)
        when :harvest
          harvest_some(command,data,client_socket_path)
        when :init
          ask_for_init_status(command,data,client_socket_path)
        when :init_crop
          answer_init_status(command,data,client_socket_path)
        when :seed_all
          seed_for_all_rows(command,data,client_socket_path)
        when :seed_all_crop
          special_crop_seed_all(command,data,client_socket_path)
        when :close
          close_all(command,data,client_socket_path)
        else
          socket_send(command,false,client_socket_path)
        end
      end
    end
  end

end