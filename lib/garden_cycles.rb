class Garden
  # Author:: lp (mailto:lp@spiralix.org)
  # Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
  # :title:Cycles
  module Cycles
    
    def set_my_containers
      @quit = false; @full_crop = false; @do_init = nil; @seed_all = nil; @init_all_crop = []
      @harvest = []; @rows_socket_paths = []; @init_done = []; @seed_all_done = []; @seed_all_crop = []
      @seeds = []; @sprouts = []; @crops = []; @id = 0
    end
    
    def seed_if_row_available
       catch :fill_rows do
         loop do
           if ! @seed_all.nil? && ! @rows_socket_paths.empty? && @seed_all_done.size != @seed_all[0]
             row_socket_path = @rows_socket_paths.shift
             unless @seed_all_done.include?( row_socket_path )
               socket_send(:seed_all,:garden,@seed_all[1],row_socket_path)
               @seed_all_done << row_socket_path
             else
               @rows_socket_paths << row_socket_path
             end
           elsif ! @do_init.nil? && ! @rows_socket_paths.empty? && @init_done.size != @do_init
             row_socket_path = @rows_socket_paths.shift
             unless @init_done.include?( row_socket_path )
               socket_send(:init,:garden,'init_status',row_socket_path)
               @init_done << row_socket_path
             else
               @rows_socket_paths << row_socket_path
             end
           elsif ! @seeds.empty? && ! @rows_socket_paths.empty?
             seed = @seeds.shift
             @sprouts[seed[:id]] = seed
             row_socket_path = @rows_socket_paths.shift
             socket_send(:sprout,:garden,seed,row_socket_path)
           elsif @quit && ! @rows_socket_paths.empty?
             seed = nil
             row_socket_path = @rows_socket_paths.shift
             socket_send(:quit,:garden,seed,row_socket_path)
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
         socket_send(message_block[0],:garden,@id,message_block[3])
       else
         @seed_all = [message_block[1], message_block[2]]
         @seed_all_return = {:client_socket_path => message_block[3], :data => []}
       end
     end
     
     def this_row_is_available(message_block)
       if @quit
         message_block[0] = :quit; seed = nil
       elsif @seeds.empty?
         seed = nil; @rows_socket_paths << message_block[2]
       else
         seed = @seeds.shift; @sprouts[seed[:id]] = seed
       end
       socket_send(message_block[0],:garden,seed,message_block[3])
     end
     
     def save_crop_for(message_block)
       @sprouts[message_block[2][:id]] = nil
       @crops[message_block[2][:id]] = message_block[2]
       if @harvest[message_block[2][:id]]
         socket_send(message_block[0],:garden,message_block[2], @harvest[message_block[2][:id]][:client_socket_path]) 
         @crops[message_block[2][:id]] = @harvest[message_block[2][:id]] = nil
       elsif @full_crop && @seeds.compact.empty? && @sprouts.compact.empty?
         socket_send(message_block[0],:garden,@crops.compact,@mem_client_socket_path)
         @crops.clear; @full_crop = false
       end
     end
     
     def report_growth(message_block)
       case message_block[2]
       when :progress
         value = @crops.size.to_f / (@crops.size + @sprouts.compact.size + @seeds.size)
         value = 1 if value.nan?; progress = sprintf( "%.2f", value)
         socket_send(message_block[0],:garden,progress,message_block[3])
       when :seed
         socket_send(message_block[0],:garden,@seeds.size,message_block[3])
       when :sprout
         socket_send(message_block[0],:garden,@sprouts.compact.size,message_block[3])
       when :crop
         socket_send(message_block[0],:garden,@crops.size,message_block[3])
       else
         socket_send(message_block[0],:garden,false,message_block[3])
       end
     end
     
     def harvest_some(message_block)
       case message_block[2]
       when :all
         socket_send(message_block[0],:garden,{:seeds => @seeds, :sprouts => @sprouts.compact, :crops => @crops.compact},message_block[3])
       when :seed
         socket_send(message_block[0],:garden,@seeds,message_block[3])
       when :sprout
         socket_send(message_block[0],:garden,@sprouts.compact,message_block[3])
       when :crop
         socket_send(message_block[0],:garden,@crops.compact,message_block[3])
         @crops.clear
       when :full_crop
         if @seeds.compact.empty? && @sprouts.compact.empty?
           socket_send(message_block[0],:garden,@crops.compact,message_block[3])
           @crops.clear
         else
           @full_crop = true
           @mem_client_socket_path = message_block[3]
         end
       else
         if message_block[2].is_a? Integer
           if @crops[message_block[2]]
             socket_send(message_block[0],:garden,@crops[message_block[2]],message_block[3])
             @crops[message_block[2]] = nil
           else
             @harvest[message_block[2]] = {:client_socket_path => message_block[3]}
           end
         else
           socket_send(message_block[0],:garden,false,message_block[3])
         end
       end
     end
     
     def ask_for_init_status(message_block)
       @do_init = message_block[2]
       @init_return = {:client_socket_path => message_block[3]}
     end
     
     def answer_init_status(message_block)
       @init_all_crop << message_block[2]
       if @init_all_crop.size == @do_init
         socket_send(message_block[0],:garden,@init_all_crop, @init_return[:client_socket_path])
         @init_return = Hash.new; @init_done = Array.new; @do_init = nil; @init_all_crop = Array.new
       end
     end
     
     def special_crop_seed_all(message_block)
       @seed_all_crop << message_block[2]
       if @seed_all_crop.size == @seed_all[0]
         socket_send(message_block[0],:garden,@seed_all_crop, @seed_all_return[:client_socket_path])
         @seed_all = nil; @seed_all_return = Hash.new; @seed_all_done = Array.new; @seed_all_crop = Array.new
       end
     end
     
     def close_all(message_block)
       if message_block[2][:level] == :garden
         @seeds_pid = message_block[2][:pid]
         @quit = true
         @mem_client_socket_path = message_block[3]
       else
         @seeds_pid.delete(message_block[2][:pid].to_i)
         if @seeds_pid.empty?
           socket_send(:close,:garden,{:seeds => @seeds, :sprouts => @sprouts.compact, :crops => @crops.compact}, @mem_client_socket_path)
           exit
         end
       end
     end
     
  end
end