class Seed
  
  def sprout
    return $seed[:seed]
  end
  
  def crop(success,message)
    $seed[:success] = success; $seed[:message] = message
  end
  
end