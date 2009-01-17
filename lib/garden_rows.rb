class Garden
  
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
  
  # Author:: lp (mailto:lp@spiralix.org)
  # Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
  # :title:Rows
  
  class Rows
    require 'toolshed'
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
                message_block = socket_duplex([:row,:row,my_socket_path,@garden_path])
                case message_block[1]
                when :sprout
                  $seed = message_block[2]
                when :all
                  @seed_all = true
                  $seed = {:id => Process.pid, :seed => message_block[2]}
                when :wait
                  message_block = socket_recv
                  case message_block[1]
                  when :sprout
                    $seed = message_block[2]
                  when :all
                    @seed_all = true
                    $seed = {:id => Process.pid, :seed => message_block[2]}
                  when :init
                    $init = {:seed => 'init_status', :message => 'No Init Message', :id => Process.pid} if $init.nil?
                    socket_send([:crop,:init,$init,@garden_path])
                  when :quit
                    pid = Process.pid
                    socket_send([:close,:row,{:level => :seed, :pid => pid},@garden_path])
                    exit
                  end
                when :init
                  $init = {:seed => 'init_status', :message => 'No Init Message', :id => Process.pid} if $init.nil?
                  socket_send([:crop,:init,$init,@garden_path])
                when :quit
                  pid = Process.pid
                  socket_send([:close,:row,{:level => :seed, :pid => pid},@garden_path])
                  exit
                end
              elsif ! $seed[:success].nil?
                if @seed_all
                  socket_send([:crop,:seed_all,$seed,@garden_path])
                  @seed_all = false
                else
                  socket_send([:crop,:harvest,$seed,@garden_path])
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