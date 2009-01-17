$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'test/unit'
require 'abundance'

class TestHighAPI < Test::Unit::TestCase
  
  def test_abundance_monothread
    @rows = 1
    set_gardener
    reality_check
  end
  
  def test_abundance_quadthread
    @rows = 4
    set_gardener
    reality_check
  end
  
  def test_abundance_hexthread
    @rows = 16
    set_gardener
    reality_check
  end
  
  def teardown
    final = @g.close
    assert_kind_of(Hash,final)
    assert_equal(3,final.size)
    assert_not_nil(final[:seeds])
    assert_not_nil(final[:sprouts])
    assert_not_nil(final[:crops])
  end
  
  private
  
  def set_gardener
    @g = Abundance.gardener(:rows => @rows, :init_timeout => 3) do
      Abundance.init_status(true,Process.pid)
      Abundance.grow do |seed|
        seed.crop(true, "gardener: #{seed.sprout}")
      end      
    end
  end
  
  def reality_check
    assert_instance_of(Gardener,@g)
    
    check_init          
    check_seed_harvest      # leaves no crops in the queue
    check_full_harvest         # also leaves no crops in the queue
    check_deep_harvest    # may leave crap behind, so needs to come last of the harvest
    check_growth
    check_seed_all
    
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
  
  def check_seed_harvest
    id = @g.seed(Process.pid)
    assert_kind_of(Integer,id)
    
    answer = @g.harvest(:one,id)
    assert_kind_of(Hash,answer)
    assert_equal(Process.pid,answer[:seed])
    assert_equal(id,answer[:id])
    assert_equal(true,answer[:success])
    assert_equal("gardener: #{Process.pid}",answer[:message])
  end
  
  def check_full_harvest
    queue_items = {}
    25.times do |num|
      queue_items[num] = @g.seed(num)
    end
    full_crop = @g.harvest(:full_crop)
    assert_equal(25,full_crop.size)
    results = []
    queue_items.each do |num,id|
      success = false
      full_crop.each do |crop|
        success = true if crop[:id] == id && crop[:seed] == num && crop[:message] == "gardener: #{num}"
      end
      results << success
    end
    assert(results[0] == true && results.uniq.size == 1)
  end
  
  def check_growth
    progress = @g.growth(:progress)
    assert_kind_of(String,progress)
    assert(progress.to_f >= 0 && progress.to_f <= 1)
    
    seeds_growth = @g.growth(:seed)
    assert_kind_of(Integer,seeds_growth)
    sprouts_growth = @g.growth(:sprout)
    assert_kind_of(Integer,sprouts_growth)
    crops_growth = @g.growth(:crop)
    assert_kind_of(Integer,crops_growth)
  end
  
  def check_deep_harvest
    queue_items = {}
    25.times do |num|
      queue_items[num] = @g.seed(num)
    end
    
    all = @g.harvest(:all)
    assert_kind_of(Hash,all)
    assert_equal(25,all[:seeds].size + all[:sprouts].size + all[:crops].size)
    seeds_harvest = @g.harvest(:seed); assert_kind_of(Array,seeds_harvest)
    sprouts_harvest = @g.harvest(:sprout); assert_kind_of(Array,sprouts_harvest)
    crops_harvest = @g.harvest(:crop); assert_kind_of(Array,crops_harvest)
    results = []
    queue_items.each do |num,id|
      success = false
      seeds_harvest.each do |seed|
        success = true if seed[:id] == id && seed[:seed] == num
      end
      sprouts_harvest.each do |sprout|
        success = true if sprout[:id] == id && sprout[:seed] == num
      end
      crops_harvest.each do |crop|
        success = true if crop[:id] == id && crop[:seed] == num && crop[:message] == "gardener: #{num}"
      end
      results << success
    end
    assert(results[0] == true && results.uniq.size == 1)
  end
  
  def check_seed_all
    all = @g.seed_all("all")
    assert_equal(@rows,all.size)
    all.map! { |seed| seed[:message] == "gardener: all" }
    assert( all.uniq.size == 1 && all[0] == true )
  end
  
end