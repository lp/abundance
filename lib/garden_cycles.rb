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
     
     def place_seed_in_queue(command,data,client_socket_path)
       @id += 1; @seeds << {:id => @id , :seed => data}
       socket_send(command,:garden,@id,client_socket_path)
     end
     
     def this_row_is_available(command,data,client_socket_path)
       if @quit
         command = :quit; seed = nil
       elsif @seeds.empty?
         seed = nil; @rows_socket_paths << data
       else
         seed = @seeds.shift; @sprouts[seed[:id]] = seed
       end
       socket_send(command,:garden,seed,client_socket_path)
     end
     
     def save_crop_for(command,data,client_socket_path)
       @sprouts[data[:id]] = nil; @crops[data[:id]] = data
       if @harvest[data[:id]]
         socket_send(command,:garden,data, @harvest[data[:id]][:client_socket_path]) 
         @crops[data[:id]] = @harvest[data[:id]] = nil
       elsif @full_crop && @seeds.compact.empty? && @sprouts.compact.empty?
         socket_send(command,:garden,@crops.compact,@mem_client_socket_path)
         @crops.clear; @full_crop = false
       end
     end
     
     def report_growth(command,data,client_socket_path)
       case data
       when :progress
         value = @crops.size.to_f / (@crops.size + @sprouts.compact.size + @seeds.size)
         value = 1 if value.nan?; progress = sprintf( "%.2f", value)
         socket_send(command,:garden,progress,client_socket_path)
       when :seed
         socket_send(command,:garden,@seeds.size,client_socket_path)
       when :sprout
         socket_send(command,:garden,@sprouts.compact.size,client_socket_path)
       when :crop
         socket_send(command,:garden,@crops.size,client_socket_path)
       else
         socket_send(command,:garden,false,client_socket_path)
       end
     end
     
     def harvest_some(command,data,client_socket_path)
       case data
       when :all
         socket_send(command,:garden,{:seeds => @seeds, :sprouts => @sprouts.compact, :crops => @crops.compact},client_socket_path)
       when :seed
         socket_send(command,:garden,@seeds,client_socket_path)
       when :sprout
         socket_send(command,:garden,@sprouts.compact,client_socket_path)
       when :crop
         socket_send(command,:garden,@crops.compact,client_socket_path)
         @crops.clear
       when :full_crop
         if @seeds.compact.empty? && @sprouts.compact.empty?
           socket_send(command,:garden,@crops.compact,client_socket_path)
           @crops.clear
         else
           @full_crop = true
           @mem_client_socket_path = client_socket_path
         end
       else
         if data.is_a? Integer
           if @crops[data]
             socket_send(command,:garden,@crops[data],client_socket_path)
             @crops[data] = nil
           else
             @harvest[data] = {:client_socket_path => client_socket_path}
           end
         else
           socket_send(command,:garden,false,client_socket_path)
         end
       end
     end
     
     def ask_for_init_status(command,data,client_socket_path)
       @do_init = data
       @init_return = {:client_socket_path => client_socket_path}
     end
     
     def answer_init_status(command,data,client_socket_path)
       @init_all_crop << data
       if @init_all_crop.size == @do_init
         socket_send(command,:garden,@init_all_crop, @init_return[:client_socket_path])
         @init_return = Hash.new; @init_done = Array.new; @do_init = nil; @init_all_crop = Array.new
       end
     end
     
     def seed_for_all_rows(command,data,client_socket_path)
       @seed_all = data
       @seed_all_return = {:client_socket_path => client_socket_path, :data => []}
     end
     
     def special_crop_seed_all(command,data,client_socket_path)
       @seed_all_crop << data
       if @seed_all_crop.size == @seed_all[0]
         socket_send(command,:garden,@seed_all_crop, @seed_all_return[:client_socket_path])
         @seed_all = nil; @seed_all_return = Hash.new; @seed_all_done = Array.new; @seed_all_crop = Array.new
       end
     end
     
     def close_all(command,data,client_socket_path)
       if data[:level] == :garden
         @seeds_pid = data[:pid]
         @quit = true
         @mem_client_socket_path = client_socket_path
       else
         @seeds_pid.delete(data[:pid].to_i)
         if @seeds_pid.empty?
           socket_send(:close,:garden,{:seeds => @seeds, :sprouts => @sprouts.compact, :crops => @crops.compact}, @mem_client_socket_path)
           exit
         end
       end
     end
     
  end
end