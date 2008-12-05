# This class provides the seed part of the Gardener,Garden,Seed natural design patern
# 
# In nature, seed is usually small, and so is this class.
# No atributes/variables of itself, its only a kind of localized getter/setter class for 
# the global $seed variable.  Every garden row assess one fork-localized $seed variable, and
# you get access to it from a +seed+ instance passed to every Abundance.grow iteration.
# 
# Author:: lp (mailto:lp@spiralix.org)
# Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
# 
# :title:Seed

class Seed
  
  # The +new+ class method initializes the class.
  # You don't have to initialize it inside of Abundance,
  # as it gets initialized automatically inside the +Abundance.grow+ method
  
  # The +sprout+ method for the Seed instance allow to get the passed command 
  # from the inside the Abundance.grow block.
  # === Example
  #  system "#{seed.sprout}\n"
  def sprout
    return $seed[:seed]
  end
  
  # The +crop+ method for the Seed instance allow to set a success status and
  # a return message from the inside the Abundance.grow block.
  # === Parameter
  # * _success_ = success of the iteration, may be true or false
  # * _message_ = a ruby expression or object
  # === Example
  #  if success
  #   seed.crop(true,results)
  #  else
  #   seed.crop(false,results)
  #  end
  def crop(success,message)
    $seed[:success] = success; $seed[:message] = message
  end
  
end