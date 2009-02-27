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
				$log_abundance.debug("Rows::Paths") {"all"}
        $seed = {:id => Process.pid, :seed => message_block[2], :all => true}
      end
      
      def crop
				$log_abundance.debug("Rows::Paths") {"crop, seed: #{$seed.inspect}"}
        if $seed[:all]
          socket_send([:crop,:seed_all,$seed,@garden_path])
        else
          socket_send([:crop,:harvest,$seed,@garden_path])
        end
        $seed = nil
      end
      
      def init
				$log_abundance.debug("Rows::Paths") {"init"}
        $init = {:seed => 'init_status', :success => false, :message => 'No Init Message', :id => Process.pid} if $init.nil?
        socket_send([:crop,:init,$init,@garden_path])
      end
      
      def quit
				$log_abundance.debug("Rows::Paths") {"quit"}
        socket_send([:close,:row,Process.pid,@garden_path])
        Thread::exit
      end
      
      def sprout(message_block)
				$log_abundance.debug("Rows::Paths") {"sprout"}
        $seed = message_block[2]
      end
      
    end
  end
end