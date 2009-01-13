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
      @quit = false; @full_crop = false; @do_init = nil; @seed_all = nil; @init_all_crop = []
      @harvest = []; @rows_socket_paths = []; @init_done = []; @seed_all_done = []; @seed_all_crop = []
      @seeds = []; @sprouts = []; @crops = []; @id = 0
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
    return pid
  end
  
  # The +rows+ method for the Garden instance allow instantiation of its child Rows.
  # As part of the Abundance lib, Garden.rows is not invoked directly, 
  # but rather as a side effect of the Gardener's initialization.
  # Its in reality an indirect initializer for the Rows class.
  # === Parameter
  # * _rows_ = garden rows number, the number of concurent threads
  # * _init_timeout_ = allow to pause execution to allow for larger garden rows to initialize
  # === Example
  #  rows = garden.rows(4,2) { grow_block }
  # 
  
  def rows(rows,init_timeout,grow_block)
    Rows.new(rows,init_timeout,@pid,grow_block)
  end
  
  # :title:Rows
  
  class Rows
    include Toolshed
    attr_reader :pids
    
    # The +new+ class method initializes the Rows.
    # As part of the Abundance lib, Rows is not initialized directly, 
    # but rather as a side effect of the Gardener's initialization,
    # through the +rows+ Garden instance method.
    # Its instance resides in the @garden_rows Gardener's instance variable.
    # Its real muscles are inaccessibles from instance method intervention,
    # because of its nature as a forked Ruby process.
    # === Parameter
    # * _rows_ = garden rows number, the number of concurent threads
    # * _init_timeout_ = allow to pause execution to allow for larger garden rows to initialize
    # * _garden_pid_ = the parent Garden's pid, for loopback communication purpose
    # === Example
    #  rows = Rows.new(4,2) { grow_block }
    
    def initialize(rows,init_timeout,garden_pid,gardener_block)
      @pids = []
      rows.times do
        @pids << fork do
          @seed_all = false
          set_my_socket_as_a(:row,garden_pid)
          t1 = Thread.new do
            gardener_block.call
          end

          t2 = Thread.new do
            loop do
              if $seed.nil?
                command, data = socket_duplex(:row,my_socket_path)
                if command == :quit
                  pid = Process.pid
                  socket_send(:close,{:level => :seed, :pid => pid})
                  exit
                end
                $seed = data
                if $seed.nil?
                  command, data, client_socket_path = socket_recv
                  case command
                  when :sprout
                    $seed = data
                  when :seed_all
                    @seed_all = true
                    $seed = {:id => Process.pid, :seed => data}
                  when :init
                    $init = {:seed => 'init_status', :message => 'No Init Message', :id => Process.pid} if $init.nil?
                    socket_send(:init_crop,$init)
                  end
                end
              elsif ! $seed[:success].nil?
                if @seed_all
                  socket_send(:seed_all_crop,$seed)
                  @seed_all = false
                else
                  socket_send(:crop,$seed)
                end
                $seed = nil;
              else
                t1.run
              end
            end
          end
          t2.join
        end
      end
      sleep init_timeout
    end
  end
end