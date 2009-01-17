class Garden
  # Author:: lp (mailto:lp@spiralix.org)
  # Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
  # :title:Cycles
  module Cycles
    
    def set_my_containers
      @quit = false; @full_crop = false; @do_init = nil; @seed_all_message_block = nil; @init_all_crop = []
      @harvest = []; @rows_socket_paths = []; @init_done = []; @seed_all_done = []; @seed_all_crop = []
      @seeds = []; @sprouts = []; @crops = []; @id = 0
    end
    
    def seed_if_row_available
       catch :fill_rows do
         loop do
           if ! @seed_all_message_block.nil? && ! @rows_socket_paths.empty? && @seed_all_done.size != @seed_all_message_block[1]
             row_socket_path = @rows_socket_paths.shift
             unless @seed_all_done.include?( row_socket_path )
               socket_send([:seed,:all,@seed_all_message_block[2],row_socket_path])
               @seed_all_done << row_socket_path
             else
               @rows_socket_paths << row_socket_path
             end
           elsif ! @do_init.nil? && ! @rows_socket_paths.empty? && @init_done.size != @do_init
             row_socket_path = @rows_socket_paths.shift
             unless @init_done.include?( row_socket_path )
               socket_send([:seed,:init,'init_status',row_socket_path])
               @init_done << row_socket_path
             else
               @rows_socket_paths << row_socket_path
             end
           elsif ! @seeds.empty? && ! @rows_socket_paths.empty?
             seed = @seeds.shift; @sprouts[seed[:id]] = seed
             socket_send([:seed,:sprout,seed,@rows_socket_paths.shift])
           elsif @quit && ! @rows_socket_paths.empty?
             socket_send([:seed,:quit,nil,@rows_socket_paths.shift])
           else
             throw :fill_rows
           end               
         end
       end
     end
     
     def place_seed_in_queue(message_block)
       case message_block[1]
       when :one
         @id += 1; @seeds << {:id => @id , :seed => message_block[2]}
         message_block[2] = @id; socket_send(message_block)
       else
         @seed_all_message_block = Array.new(message_block)
       end
     end
     
     def this_row_is_available(message_block)
       if @quit
         message_block = [:row, :quit, nil, message_block[3]]
       elsif ! @seed_all_message_block.nil? && @seed_all_done.size != @seed_all_message_block[1] && ! @seed_all_done.include?( message_block[3] )
         message_block = [:row, :all, @seed_all_message_block[2], message_block[3]]
         @seed_all_done << message_block[3]
       elsif ! @do_init.nil? && @init_done.size != @do_init && ! @init_done.include?( message_block[3] )
         message_block = [:row, :init, 'init_status', message_block[3]]
         @init_done << message_block[3]
       elsif @seeds.empty?
         @rows_socket_paths << message_block[2]
         message_block = [:row, :wait, nil, message_block[3]]
       else
         seed = @seeds.shift; @sprouts[seed[:id]] = seed
         message_block = [:row, :sprout, seed, message_block[3]]
       end
       socket_send(message_block)
     end
     
     def save_crop_for(message_block)
       case message_block[1]
       when :harvest
         @sprouts[message_block[2][:id]] = nil
         @crops[message_block[2][:id]] = message_block[2]
         if @harvest[message_block[2][:id]]
           socket_send(message_block[0..2]+[@harvest[message_block[2][:id]][:client_socket_path]]) 
           @crops[message_block[2][:id]] = @harvest[message_block[2][:id]] = nil
         elsif @full_crop && @seeds.compact.empty? && @sprouts.compact.empty?
           socket_send(message_block[0..1]+[@crops.compact,@mem_client_socket_path])
           @crops.clear; @full_crop = false
         end
       when :seed_all
         @seed_all_crop << message_block[2]
         if @seed_all_crop.size == @seed_all_message_block[1]
           socket_send(message_block[0..1]+[@seed_all_crop, @seed_all_message_block[3]])
           @seed_all_message_block = nil; @seed_all_done = Array.new; @seed_all_crop = Array.new
         end
       when :init
         @init_all_crop << message_block[2]
         if @init_all_crop.size == @do_init
           socket_send(message_block[0..1]+[@init_all_crop, @init_return[:client_socket_path]])
           @init_return = Hash.new; @init_done = Array.new; @do_init = nil; @init_all_crop = Array.new
         end
       end
     end
     
     def report_growth(message_block)
       case message_block[1]
       when :progress
         value = @crops.size.to_f / (@crops.size + @sprouts.compact.size + @seeds.size)
         value = 1 if value.nan?; progress = sprintf( "%.2f", value)
         message_block[2] = progress
       when :seed
         message_block[2] = @seeds.size
       when :sprout
         message_block[2] = @sprouts.compact.size
       when :crop
         message_block[2] = @crops.size
       else
         message_block[2] = false
       end
       socket_send(message_block)
     end
     
     def harvest_some(message_block)
       case message_block[1]
       when :one
         unless message_block[2].nil?
           if @crops[message_block[2]]
             socket_send(message_block[0..1]+[@crops[message_block[2]],message_block[3]])
             @crops[message_block[2]] = nil
           else
             @harvest[message_block[2]] = {:client_socket_path => message_block[3]}
           end
         else
           message_block[2] = false; socket_send(message_block)
         end
       when :all
         message_block[2] = {:seeds => @seeds, :sprouts => @sprouts.compact, :crops => @crops.compact}
         socket_send(message_block)
       when :seed
         message_block[2] = @seeds; socket_send(message_block)
       when :sprout
         message_block[2] = @sprouts.compact; socket_send(message_block)
       when :crop
         message_block[2] = @crops.compact; socket_send(message_block); @crops.clear
       when :full_crop
         if @seeds.compact.empty? && @sprouts.compact.empty?
           message_block[2] = @crops.compact; socket_send(message_block); @crops.clear
         else
           @full_crop = true
           @mem_client_socket_path = message_block[3]
         end
       when :init
         @do_init = message_block[2]
         @init_return = {:client_socket_path => message_block[3]}
       else
         message_block[2] = false; socket_send(message_block)
       end
     end
           
     def close_all(message_block)
       case message_block[1]
       when :garden
         @quit = true
         @close_message_block = Array.new(message_block)
       when :row
         @close_message_block[2].delete(message_block[2].to_i)
         if @close_message_block[2].empty?
           @close_message_block[2] = {:seeds => @seeds, :sprouts => @sprouts.compact, :crops => @crops.compact}
           socket_send(@close_message_block)
           exit
         end
       end
     end
     
  end
end