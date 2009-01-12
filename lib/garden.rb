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
      @quit = false; @full_crop = false; @do_init = nil; @seed_all = nil; @init_all_crop = []
      @harvest = []; @rows_socket_paths = []; @init_done = []; @seed_all_done = []; @seed_all_crop = []
      @seeds = []; @sprouts = []; @crops = []; @id = 0
      set_my_socket_as_a(:garden)
      loop do
        catch :fill_rows do
          loop do
            if ! @seed_all.nil? && ! @rows_socket_paths.empty? && @seed_all_done.size != @seed_all[0]
              row_socket_path = @rows_socket_paths.shift
              unless @seed_all_done.include?( row_socket_path )
                socket_send(:seed_all,@seed_all[1],row_socket_path)
                @seed_all_done << row_socket_path
              else
                @rows_socket_paths << row_socket_path
              end
            elsif ! @do_init.nil? && ! @rows_socket_paths.empty? && @init_done.size != @do_init
              row_socket_path = @rows_socket_paths.shift
              unless @init_done.include?( row_socket_path )
                socket_send(:init,'init_status',row_socket_path)
                @init_done << row_socket_path
              else
                @rows_socket_paths << row_socket_path
              end
            elsif ! @seeds.empty? && ! @rows_socket_paths.empty?
              seed = @seeds.shift
              @sprouts[seed[:id]] = seed
              row_socket_path = @rows_socket_paths.shift
              socket_send(:sprout,seed,row_socket_path)
            elsif @quit && ! @rows_socket_paths.empty?
              seed = nil
              row_socket_path = @rows_socket_paths.shift
              socket_send(:quit,seed,row_socket_path)
            else
              throw :fill_rows
            end               
          end
        end
        command, data, client_socket_path = socket_recv
        case command
        when :seed
          @id += 1; @seeds << {:id => @id , :seed => data}
          socket_send(command,@id,client_socket_path)
        when :row
          if @quit
            command = :quit
            seed = nil
          elsif @seeds.empty?
            seed = nil
            @rows_socket_paths << data
          else
            seed = @seeds.shift
            @sprouts[seed[:id]] = seed
          end
          socket_send(command,seed,client_socket_path)  
        when :crop
          @sprouts[data[:id]] = nil
          @crops[data[:id]] = data
          if @harvest[data[:id]]
            socket_send(command,data, @harvest[data[:id]][:client_socket_path]) 
            @crops[data[:id]] = @harvest[data[:id]] = nil
          elsif @full_crop && @seeds.compact.empty? && @sprouts.compact.empty?
            socket_send(command,@crops.compact,@mem_client_socket_path)
            @crops.clear; @full_crop = false
          end
        when :growth
          case data
          when :progress
            value = @crops.size.to_f / (@crops.size + @sprouts.compact.size + @seeds.size)
            value = 1 if value.nan?; progress = sprintf( "%.2f", value)
            socket_send(command,progress,client_socket_path)
          when :seed
            socket_send(command,@seeds.size,client_socket_path)
          when :sprout
            socket_send(command,@sprouts.compact.size,client_socket_path)
          when :crop
            socket_send(command,@crops.size,client_socket_path)
          else
            socket_send(command,false,client_socket_path)
          end
        when :harvest
          case data
          when :all
            socket_send(command,{:seeds => @seeds, :sprouts => @sprouts.compact, :crops => @crops.compact},client_socket_path)
          when :seed
            socket_send(command,@seeds,client_socket_path)
          when :sprout
            socket_send(command,@sprouts.compact,client_socket_path)
          when :crop
            socket_send(command,@crops.compact,client_socket_path)
            @crops.clear
          when :full_crop
            if @seeds.compact.empty? && @sprouts.compact.empty?
              socket_send(command,@crops.compact,client_socket_path)
              @crops.clear
            else
              @full_crop = true
              @mem_client_socket_path = client_socket_path
            end
          else
            if data.is_a? Integer
              if @crops[data]
                socket_send(command,@crops[data],client_socket_path)
                @crops[data] = nil
              else
                @harvest[data] = {:client_socket_path => client_socket_path}
              end
            else
              socket_send(command,false,client_socket_path)
            end
          end
        when :init
          @do_init = data
          @init_return = {:client_socket_path => client_socket_path}
        when :init_crop
          @init_all_crop << data
          if @init_all_crop.size == @do_init
            socket_send(command,@init_all_crop, @init_return[:client_socket_path])
            @init_return = Hash.new; @init_done = Array.new; @do_init = nil; @init_all_crop = Array.new
          end
        when :seed_all
          @seed_all = data
          @seed_all_return = {:client_socket_path => client_socket_path, :data => []}
        when :seed_all_crop
          @seed_all_crop << data
          if @seed_all_crop.size == @seed_all[0]
            socket_send(command,@seed_all_crop, @seed_all_return[:client_socket_path])
            @seed_all = nil; @seed_all_return = Hash.new; @seed_all_done = Array.new; @seed_all_crop = Array.new
          end
        when :close
          if data[:level] == :garden
            @seeds_pid = data[:pid]
            @quit = true
            @mem_client_socket_path = client_socket_path
          else
            @seeds_pid.delete(data[:pid].to_i)
            if @seeds_pid.empty?
              socket_send(:close,{:seeds => @seeds, :sprouts => @sprouts.compact, :crops => @crops.compact}, @mem_client_socket_path)
              exit
            end
          end
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