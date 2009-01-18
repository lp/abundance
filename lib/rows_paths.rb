class Garden
  class Rows
    # The Paths module is a set of method used by the Rows's forks.
    # You will not need to use these methods unless you plan on refactoring the Rows.
    #
    # Author:: lp (mailto:lp@spiralix.org)
    # Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
    # :title:Rows
    module Paths
      
      def all(message_block)
        $seed = {:id => Process.pid, :seed => message_block[2], :all => true}
      end
      
      def crop
        if $seed[:all]
          socket_send([:crop,:seed_all,$seed,@garden_path])
        else
          socket_send([:crop,:harvest,$seed,@garden_path])
        end
        $seed = nil
      end
      
      def init
        $init = {:seed => 'init_status', :message => 'No Init Message', :id => Process.pid} if $init.nil?
        socket_send([:crop,:init,$init,@garden_path])
      end
      
      def quit
        socket_send([:close,:row,Process.pid,@garden_path])
        exit
      end
      
      def sprout(message_block)
        $seed = message_block[2]
      end
      
    end
  end
end