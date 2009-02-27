require 'rubygems'
require 'globalog'
require 'test/unit'
require File.join( File.dirname( File.expand_path(__FILE__)), '..', 'lib', 'abundance')

class TestHighAPI < Test::Unit::TestCase
	
	def setup
		@log_test = GlobaLog.logger(STDERR,:info)
	end
  
  def test_1_abundance_monothread
		@log_test.info("Test High API") {"testing 1 thread..."}
    @rows = 1
    set_gardener
    reality_check
  end
  
  def test_2_abundance_quadthread
		@log_test.info("Test High API") {"testing 4 thread..."}
    @rows = 4
    set_gardener
    reality_check
  end
  
  def test_3_abundance_hexthread
		@log_test.info("Test High API") {"testing 16 thread..."}
    @rows = 16
    set_gardener
    reality_check
  end
  
  def teardown
		@log_test.info("Test High API") {"tearing down..."}
    final = @g.close
    assert_kind_of(Hash,final,"close method didn't return a Hash, it returned: #{final.inspect}")
    assert_equal(3,final.size,"Hash returned on close has wrong size, here it is: #{final.inspect}")
    assert_not_nil(final[:seeds],"close Hash has Nil value for :seeds instead of an Array")
    assert_not_nil(final[:sprouts],"close Hash has Nil value for :sprouts instead of an Array")
    assert_not_nil(final[:crops],"close Hash has Nil value for :crops instead of an Array")
  end
  
  private
  
  def set_gardener
    @g = Abundance.gardener(:rows => @rows, :init_timeout => 3) do
      Abundance.init_status(true,Process.pid)
      Abundance.grow do |seed|
        if seed.sprout.nil?
          seed.crop(false, "gardener has no seed")
        else
          seed.crop(true, "gardener: #{seed.sprout}")
        end
      end      
    end
  end
  
  def reality_check
    assert_instance_of(Gardener,@g)
    
    check_init
    check_false     
    check_seed_harvest      # leaves no crops in the queue
    check_full_harvest         # also leaves no crops in the queue
    check_deep_harvest    # may leave crap behind, so needs to come last of the harvest
    check_growth
    check_seed_all
    
  end
  
  def check_init
    @g.init_status.each do |init|
      assert_not_nil(init[:message],"init :message value is Nil instead of String")
      assert_not_nil(init[:success],"init :success value is Nil instead of True || False")
      assert_not_nil(init[:pid],"init :pid value is Nil instead of Numeric")
    
      assert_not_equal(Process.pid,init[:message],"init has same pid than test process, something has gone wrong in the forking...")
      assert_equal(init[:message],init[:pid],"init :pid should be the row pid, it isn't")
    end
  end
  
  def check_false
    id = @g.seed(nil)
    answer = @g.harvest(:one,id)
    assert_equal(false,answer[:success],"failed returning a seed for which :success value was false")
  end
  
  def check_seed_harvest
    id = @g.seed(Process.pid)
    assert_kind_of(Integer,id,"seed method failed returning and Integer")
    
    answer = @g.harvest(:one,id)
    assert_kind_of(Hash,answer,"harvest :one method failed to return a seed Hash, got #{answer.inspect} instead.")
    assert_equal(Process.pid,answer[:seed], "harvesting showed a problem with seeding flow, seed[:seed] had wrong return value")
    assert_equal(id,answer[:id], "harvesting showed a problem with seeding flow, seed[:id] had wrong return value")
    assert_equal(true,answer[:success], "harvesting showed a problem with seeding flow, seed[:success] had wrong return value")
    assert_equal("gardener: #{Process.pid}",answer[:message], "harvesting showed a problem with seeding flow, seed[:message] had wrong return value")
  end
  
  def check_full_harvest
    queue_items = {}
    25.times do |num|
      queue_items[num] = @g.seed(num)
    end
    full_crop = @g.harvest(:full_crop)
    assert_equal(25,full_crop.size, "a :full_crop harvest has shown some seeds were lost during processing")
    results = []
    queue_items.each do |num,id|
      success = false
      full_crop.each do |crop|
        success = true if crop[:id] == id && crop[:seed] == num && crop[:message] == "gardener: #{num}"
      end
      results << success
    end
    assert(results[0] == true && results.uniq.size == 1, "a :full_crop harvest has shown processing to be inconsistent amongst rows")
  end
  
  def check_growth
    progress = @g.growth(:progress)
    assert_kind_of(String,progress, "the growth :progress method doesn't return proper value")
    assert(progress.to_f >= 0 && progress.to_f <= 1, "the growth :progress method doesn't return a value between 0 and 1")
    
    seeds_growth = @g.growth(:seed)
    assert_kind_of(Integer,seeds_growth, "the growth :seed method doesn't return proper value")
    sprouts_growth = @g.growth(:sprout)
    assert_kind_of(Integer,sprouts_growth, "the growth :sprout method doesn't return proper value")
    crops_growth = @g.growth(:crop)
    assert_kind_of(Integer,crops_growth, "the growth :crop method doesn't return proper value")
  end
  
  def check_deep_harvest
    queue_items = {}
    25.times do |num|
      queue_items[num] = @g.seed(num)
    end
    
    all = @g.harvest(:all)
    assert_kind_of(Hash,all, "the harvest :all method doesn't return a Hash as supposed")
    assert_equal(25,all[:seeds].size + all[:sprouts].size + all[:crops].size, "the harvest :all method returns a total of items not coherent with amount of seeded items")
    seeds_harvest = @g.harvest(:seed); assert_kind_of(Array,seeds_harvest, "the harvest :seed method doesn't return an Array as supposed")
    sprouts_harvest = @g.harvest(:sprout); assert_kind_of(Array,sprouts_harvest, "the harvest :sprout method doesn't return an Array as supposed")
    crops_harvest = @g.harvest(:crop); assert_kind_of(Array,crops_harvest, "the harvest :crop method doesn't return an Array as supposed")
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
    assert(results[0] == true && results.uniq.size == 1, "the harvest :all method has shown processing to be inconsistent amongst rows")
  end
  
  def check_seed_all
    all = @g.seed_all("all")
    assert_equal(@rows,all.size, "the seed_all method has missed some rows in its seeding, harvesting, or both")
    all.map! { |seed| seed[:message] == "gardener: all" }
    assert( all.uniq.size == 1 && all[0] == true, "the seed_all method shows an inconsistency amongst row processing")
  end
  
end