# This class provides the seed part of the Gardener,Garden,Seed natural design patern
# 
# Author:: lp (mailto:lp@spiralix.org)
# Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
# 
# :title:Seed

class Seed
  
  def sprout
    return $seed[:seed]
  end
  
  def crop(success,message)
    $seed[:success] = success; $seed[:message] = message
  end
  
end