$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'test/unit'
require 'abundance'

class TestHighAPI < Test::Unit::TestCase
  
  def test_abundance_robust
    @rows = 64
    hyper_gardener
  end
  
  def teardown
    @g.close
  end

  private

  def hyper_gardener
    @g = Abundance.gardener(:seed_size => 8192, :rows => @rows, :init_timeout => 3) do
      Abundance.init_status(true,Process.pid)
      Abundance.grow do |seed|
        seed.crop(true, "gardener: #{seed.sprout}")
      end      
    end
  end
  
end