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
      @quit = false
      @harvest = []
      @rows_port = []
      @seeds = []; @sprouts = []; @crops = []; @id = 0
      @socket_server = Toolshed.socket_server(Toolshed::garden_port)
      @socket_client_temp = Toolshed.socket_client_temp
      loop do
        catch :fill_rows do
          loop do
            if ! @seeds.empty? && ! @rows_port.empty?
              seed = @seeds.shift
              @sprouts[seed[:id]] = seed
              row_port = @rows_port.shift
              socket_client_temp(:sprout,seed,row_port)
            elsif @quit && ! @rows_port.empty?
              seed = nil
              row_port = @rows_port.shift
              socket_client_temp(:quit,seed,row_port)
            else
              throw :fill_rows
            end               
          end
        end
        command, data, clientport, clientname, clientaddr = socket_server_recv
        case command
        when :seed 
          @id += 1; @seeds << {:id => @id , :seed => data}
          socket_server_send(command,@id,clientaddr,clientport)
        when :row
          if @quit
            command = :quit
            seed = nil
          elsif @seeds.empty?
            seed = nil
            @rows_port << data
          else
            seed = @seeds.shift
            @sprouts[seed[:id]] = seed
          end
          socket_server_send(command,seed,clientaddr,clientport)  
        when :crop 
          @sprouts[data[:id]] = nil
          @crops[data[:id]] = data; socket_server_send(command,true,clientaddr,clientport)
          socket_server_send(command,data, @harvest[data[:id]][:clientaddr], @harvest[data[:id]][:clientport]) if @harvest[data[:id]] 
        when :growth
          case data
          when :progress
            value = @crops.size.to_f / (@crops.size + @sprouts.compact.size + @seeds.size)
            value = 1 if value.nan?; progress = sprintf( "%.2f", value)
            socket_server_send(command,progress,clientaddr,clientport)
          when :seed
            socket_server_send(command,@seeds.size,clientaddr,clientport)
          when :sprout
            socket_server_send(command,@sprouts.compact.size,clientaddr,clientport)
          when :crop
            socket_server_send(command,@crops.size,clientaddr,clientport)
          else
            socket_server_send(command,false,clientaddr,clientport)
          end
        when :harvest
          case data
          when :all
            socket_server_send(command,{:seeds => @seeds, :sprouts => @sprouts.compact, :crops => @crops.compact},clientaddr,clientport)
          when :seed
            socket_server_send(command,@seeds,clientaddr,clientport)
          when :sprout
            socket_server_send(command,@sprouts.compact,clientaddr,clientport)
          when :crop
            socket_server_send(command,@crops.compact,clientaddr,clientport)
            @crops.clear
          else
            if data.is_a? Integer
              if @crops[data]
                socket_server_send(command,@crops[data],clientaddr,clientport)
                @crops[data] = nil
              else
                @harvest[data] = {:clientaddr => clientaddr, :clientport => clientport}
              end
            else
              socket_server_send(command,false,clientaddr,clientport)
            end
          end
        when :close
          if data[:level] == :garden
            @seeds_pid = data[:pid]
            @quit = true
            @mem_addr = clientaddr; @mem_port = clientport
          else
            @seeds_pid.delete(data[:pid].to_i)
            if @seeds_pid.empty?
              socket_server_send(:close,{:seeds => @seeds, :sprouts => @sprouts.compact, :crops => @crops}, @mem_addr, @mem_port)
              exit
            end
          end
        else
          socket_server_send(command,false,clientaddr,clientport)
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
    Rows.new(rows,init_timeout,grow_block)
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
    # === Example
    #  rows = Rows.new(4,2) { grow_block }
    
    def initialize(rows,init_timeout,gardener_block)
      @pids = []
      rows.times do
        row_port = Toolshed.available_port
        @pids << fork do
          @socket_server = Toolshed.socket_server(row_port)
          t1 = Thread.new do
            gardener_block.call
          end

          t2 = Thread.new do
            @socket_client_perm = Toolshed.socket_client_perm
            loop do
              if $seed.nil?
                command, data = socket_client_perm_duplex(:row,row_port)
                if command == :quit
                  pid = Process.pid
                  socket_client_perm_send(:close,{:level => :seed, :pid => pid})
                  exit
                end
                $seed = data
                if $seed.nil?
                  command, data, clientport, clientname, clientaddr = socket_server_recv
                  $seed = data
                end
              elsif $seed.include?(:success)
                command, data = socket_client_perm_duplex(:crop,$seed)
                $seed = nil
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