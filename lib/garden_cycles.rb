class Garden
  # The Cycles module is a set of method used by the Garden's fork.
  # You will not need to use these methods unless you plan on refactoring the Garden.
  # 
  # Author:: lp (mailto:lp@spiralix.org)
  # Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
  # :title:Cycles
  module Cycles
    
    def set_my_containers
      @close_message_block = nil; @full_crop_message_block = nil
      @init_message_block = nil; @seed_all_message_block = nil
      @harvest_queue = []; @waiting_rows = []; @message_block_queue = []
      @seeds = []; @sprouts = []; @crops = []; @id = 0
    end
    
    def sprout_readable(readable)
      readable.each do |i_socket|
        if i_socket == @my_socket
          add_readable(i_socket)
        else
          readable_main(i_socket)
        end
      end
    end
    
    def crop_writable(writable)
      writable.each do |o_socket|
        if @writer[:buffer][o_socket.to_s] == '' || @writer[:buffer][o_socket.to_s] == nil
          remove_writable(o_socket)
        else
          write_raw(o_socket)
        end
      end
    end
    
    def route_message_blocks
      until @message_block_queue.empty?
        message_block = @message_block_queue.shift

        case message_block[0]
        when :seed
          place_seed_in_queue(message_block)
        when :row
          this_row_is_available(message_block)  
        when :crop
          save_crop_for(message_block)
        when :growth
          report_growth(message_block)
        when :harvest
          harvest_some(message_block)
        when :close
          close_all(message_block)
        else
          message_block[2] = false
          add_writable(message_block)
        end

      end
    end

		def seed_available_rows
        catch :fill_rows do
          loop do
						throw :fill_rows if @waiting_rows.empty?
						
            if @seed_all_message_block && @seed_all_message_block[4][:row_done].size != @seed_all_message_block[1]
              row_socket_path = @waiting_rows.shift
              unless @seed_all_message_block[4][:row_done].include?( row_socket_path )
                add_writable([:seed,:all,@seed_all_message_block[2],row_socket_path])
                @seed_all_message_block[4][:row_done] << row_socket_path
              else
                @waiting_rows << row_socket_path
              end

            elsif @init_message_block && @init_message_block[4][:row_done].size != @init_message_block[2]
              row_socket_path = @waiting_rows.shift
              unless @init_message_block[4][:row_done].include?( row_socket_path )
                add_writable([:seed,:init,'init_status',row_socket_path])
                @init_message_block[4][:row_done] << row_socket_path
              else
                @waiting_rows << row_socket_path
              end

            elsif ! @seeds.empty?
              seed = @seeds.shift; @sprouts[seed[:id]] = seed
              add_writable([:seed,:sprout,seed,@waiting_rows.shift])

            elsif @close_message_block && ! @waiting_rows.empty?
              add_writable([:seed,:quit,nil,@waiting_rows.shift])

            else
              throw :fill_rows
						end
						               
          end
        end
      end
     
     private
     
     def readable_main(i_socket)
       message_block = read_message_block(i_socket)
       @message_block_queue << message_block
       @reader[:sockets].delete(i_socket)
     end
     
     def place_seed_in_queue(message_block)
       case message_block[1]
       when :one
         @id += 1; @seeds << {:id => @id , :seed => message_block[2]}
         message_block[2] = @id; add_writable(message_block)
       else
         @seed_all_message_block = Array.new(message_block)
         @seed_all_message_block[4] = {:row_done => [], :crops => []}
       end
     end
     
     def this_row_is_available(message_block)
	
       if @close_message_block
				 message_block = [:row, :quit, nil, message_block[3]]
				
       elsif @seed_all_message_block && @seed_all_message_block[4][:row_done].size != @seed_all_message_block[1] && ! @seed_all_message_block[4][:row_done].include?( message_block[3] )
         message_block = [:row, :all, @seed_all_message_block[2], message_block[3]]
         @seed_all_message_block[4][:row_done] << message_block[3]

       elsif @init_message_block && @init_message_block[4][:row_done].size != @init_message_block[2] && ! @init_message_block[4][:row_done].include?( message_block[3] )
         message_block = [:row, :init, 'init_status', message_block[3]]
         @init_message_block[4][:row_done] << message_block[3]

       elsif @seeds.empty?
         @waiting_rows << message_block[2]
         message_block = [:row, :wait, nil, message_block[3]]

       else
         seed = @seeds.shift; @sprouts[seed[:id]] = seed
         message_block = [:row, :sprout, seed, message_block[3]]

       end

       add_writable(message_block)
     end
     
     def save_crop_for(message_block)
	
       case message_block[1]
       when :harvest
         @sprouts[message_block[2][:id]] = nil
         @crops[message_block[2][:id]] = message_block[2]
         if @harvest_queue[message_block[2][:id]]
           add_writable(message_block[0..2]+[@harvest_queue[message_block[2][:id]]]) 
           @crops[message_block[2][:id]] = @harvest_queue[message_block[2][:id]] = nil
         elsif @full_crop_message_block && @seeds.compact.empty? && @sprouts.compact.empty?
           add_writable(message_block[0..1]+[@crops.compact,@full_crop_message_block[3]])
           @crops.clear; @full_crop_message_block = nil
         end

       when :seed_all
         @seed_all_message_block[4][:crops] << message_block[2]
         if @seed_all_message_block[4][:crops].size == @seed_all_message_block[1]
           @seed_all_message_block[2] = @seed_all_message_block[4][:crops]; @seed_all_message_block[4] = nil
           add_writable(@seed_all_message_block.compact); @seed_all_message_block = nil
         end

       when :init
         @init_message_block[4][:crops] << message_block[2]
         if @init_message_block[4][:crops].size == @init_message_block[2]
           @init_message_block[2] = @init_message_block[4][:crops]; @init_message_block[4] = nil
           add_writable(@init_message_block.compact); @init_message_block = nil
         end
       end

     end
     
     def report_growth(message_block)
	
       case message_block[1]
       when :progress
         value = @crops.size.to_f / (@crops.size + @sprouts.compact.size + @seeds.size)
         value = 1 if value.nan?; progress = sprintf( "%.2f", value)
         message_block[2] = progress
			 when :finished
				@seeds.empty? && @sprouts.empty? ? message_block[2] = true : message_block[2] = false
			 when :empty
				@seeds.empty? && @sprouts.empty? && @crops.empty? ? message_block[2] = true : message_block[2] = false
       when :seed
         message_block[2] = @seeds.size
       when :sprout
         message_block[2] = @sprouts.compact.size
       when :crop
         message_block[2] = @crops.compact.size
       else
         message_block[2] = "Unknow garden command: growth(#{message_block[1].to_s})"
       end

       add_writable(message_block)
     end
     
     def harvest_some(message_block)
	
       case message_block[1]
       when :one
         unless message_block[2].nil?
           if @crops[message_block[2]]
             add_writable(message_block[0..1]+[@crops[message_block[2]],message_block[3]])
             @crops[message_block[2]] = nil
           else
             @harvest_queue[message_block[2]] = message_block[3]
           end
         else
           message_block[2] = false; add_writable(message_block)
         end
       when :all
         message_block[2] = {:seeds => @seeds, :sprouts => @sprouts.compact, :crops => @crops.compact}
         add_writable(message_block)
       when :seed
         message_block[2] = @seeds; add_writable(message_block)
       when :sprout
         message_block[2] = @sprouts.compact; add_writable(message_block)
       when :crop
         message_block[2] = @crops.compact; add_writable(message_block); @crops.clear
       when :full_crop
         if @seeds.compact.empty? && @sprouts.compact.empty?
           message_block[2] = @crops.compact; add_writable(message_block); @crops.clear
         else
           @full_crop_message_block = Array.new(message_block)
         end
       when :init
         @init_message_block = Array.new(message_block)
         @init_message_block[4] = {:row_done => [], :crops => []}
       else
         message_block[2] = false; add_writable(message_block)
       end

     end
           
     def close_all(message_block)
       case message_block[1]
       when :garden
         @close_message_block = Array.new(message_block)
       when :row
         @close_message_block[2].delete(message_block[2].to_i)
         if @close_message_block[2].empty?
           @close_message_block[2] = {:seeds => @seeds, :sprouts => @sprouts.compact, :crops => @crops.compact}
           socket_send(@close_message_block)
           Kernel::exit
         end
       end
     end
     
  end
end