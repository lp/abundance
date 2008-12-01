class Gardener
  require 'lib/toolshed'
  include Toolshed
  
  def initialize(options,gardener_block)
    Toolshed::block_size = options[:seed_size]
    Toolshed::garden_port = Toolshed.available_port
    
    @garden = Garden.new
    @garden_rows = @garden.rows(options[:rows], options[:init_timeout], gardener_block)
    
    @socket_client_perm = Toolshed.socket_client_perm
  end
  
  def seed(command)
    command, data = socket_client_perm_duplex(:seed,command)
    return data
  end
  
  def growth(crop=:progress)
    command, data = socket_client_perm_duplex(:growth,crop)
    return data
  end
  
  def harvest(crop)
    command, data = socket_client_perm_duplex(:harvest,crop)
    return data
  end
  
  def close
    command, data = socket_client_perm_duplex(:close,{:level => :garden, :pid => @garden_rows.pids})
    return data
  end
  
end