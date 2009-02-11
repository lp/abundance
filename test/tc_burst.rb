$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'test/test_helpers'
require 'test/unit'
require 'abundance'

class TestBurst < Test::Unit::TestCase
  
  def test_burst1
		@log_test.info("Test Burst") {"test burst1..."}
    check_init
    seed_1000x10
    check_init
    seed_2000
    check_seed_all
    seed_2000
    check_crop
  end
  
  
  def setup
		@log_test = GlobaLog.setup(STDERR,:info)
    @g = Abundance.gardener(:wheelbarrow => 124, :rows => 8, :init_timeout => 2) do
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
  
  def teardown
		@log_test.info("test Burst") {"tearing down..."}
    @g.close
  end
  
  private
  
  def seed_1000x10
    (1..1000).each do |num1|
      (1..10).each do |num2|
        @g.seed([num1,num2])
      end
    end
  end
  
  def seed_2000
    seed = {:jo => 'ker', :lo => 'ver'}
    2000.times do
      @g.seed(seed)
    end
  end
  
  def check_init
    @g.init_status.each do |init|
      assert_not_nil(init[:message])
      assert_not_nil(init[:success])
      assert_not_nil(init[:pid])
    
      assert_not_equal(Process.pid,init[:message])
      assert_equal(init[:message],init[:pid])
    end
  end
  
  def check_seed_all
    all = @g.seed_all([1000,1000])
    assert_equal(8,all.size)
    all.map! { |seed| seed[:message] == "gardener: #{(1000**1000).to_s}" }
    assert( all.uniq.size == 1 && all[0] == true )
  end
  
  def check_crop
    crop = @g.harvest(:full_crop)
    assert_equal(14000,crop.size)
    assert_kind_of(Array,crop)
    assert_kind_of(Hash,crop[0])
    assert( ! crop[0][:success].nil? && (crop[0][:success] == true || crop[0][:success] == false))
    assert(crop[0][:seed].class == Array || crop[0][:seed].class == Hash)
    assert_kind_of(String,crop[0][:message])
    assert_kind_of(Numeric,crop[0][:id])
  end
end