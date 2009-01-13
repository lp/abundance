$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'test/unit'
require 'abundance'

class TestHighAPI < Test::Unit::TestCase
  
  def test_abundance_robust
    @seed_size = 124
    @rows = 8
    @init_timeout = 3
    hyper_gardener
    seed_3000
    seed_1000x10
  end
  
  def teardown
    @g.close
  end

  private
  
  def seed_3000
    seed = {:jo => 'ker', :lo => 'ver'}
    3000.times do
      @g.seed(seed)
    end
    crop = @g.harvest(:full_crop)
    assert_crop(crop)
  end
  
  def seed_1000x10
    (1..1000).each do |num1|
      (1..10).each do |num2|
        @g.seed([num1,num2])
      end
    end
    crop = @g.harvest(:full_crop)
    assert_crop(crop)
  end
  
  def assert_crop(crop)
    assert_kind_of(Array,crop)
    assert_kind_of(Hash,crop[0])
    assert( ! crop[0][:success].nil? && (crop[0][:success] == true || crop[0][:success] == false))
    assert(crop[0][:seed].class == Array || crop[0][:seed].class == Hash)
    assert_kind_of(String,crop[0][:message])
    assert_kind_of(Numeric,crop[0][:id])
  end

  def hyper_gardener
    @g = Abundance.gardener(:wheelbarrow => @seed_size, :rows => @rows, :init_timeout => @init_timeout) do
      Abundance.init_status(true,Process.pid)
      Abundance.grow do |seed|
        sprout = seed.sprout
        if sprout.is_a?(Hash)
          seed.crop(true, "gardener: #{sprout[:jo]} - #{sprout[:lo]}")
        elsif sprout.is_a?(Array)
          result = sprout[0] ** sprout[1]
          seed.crop(true, "gardener: #{result.to_s}")
        else
          seed.crop(true, "????????????????")
        end
      end      
    end
  end
  
end
