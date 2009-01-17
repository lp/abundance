$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'test/unit'
require 'abundance'

class TestHighAPI < Test::Unit::TestCase
  
  def test_two_gardeners
    @rows = 2
    set_gardener1
    set_gardener2
    check_both_gardener
  end
  
  def teardown
    @g1.close
    @g2.close
  end
  
  private
  
  def set_gardener1
    @g1 = Abundance.gardener(:rows => @rows, :init_timeout => 3) do
      Abundance.init_status(true,Process.pid)
      Abundance.grow do |seed|
        seed.crop(true, "gardener1: #{seed.sprout}")
      end      
    end
  end
  
  def set_gardener2
    @g2 = Abundance.gardener(:rows => @rows, :init_timeout => 3) do
      Abundance.init_status(true,Process.pid)
      Abundance.grow do |seed|
        seed.crop(true, "gardener2: #{seed.sprout}")
      end      
    end
  end
  
  def check_both_gardener
    id1 = @g1.seed(Process.pid)
    id2 = @g2.seed(Process.pid)
    
    answer1 = @g1.harvest(:one,id1)
    answer2 = @g2.harvest(:one,id2)
    
    assert(answer1[:message] != answer2[:message])
    assert(answer1[:message] =~ /gardener1.*/)
    assert(answer2[:message] =~ /gardener2.*/)
  end
  
end