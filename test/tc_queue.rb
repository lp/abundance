require 'rubygems'
require 'globalog'
require 'test/unit'
require File.join( File.dirname( File.expand_path(__FILE__)), '..', 'lib', 'abundance')

class TestQueue < Test::Unit::TestCase
	
	def setup
		@log_test = GlobaLog.logger(STDERR,:info)
		@rows = 4
		set_gardener	
	end
	
	def test_queue
		@log_test.info("Test Queue") {"test queue..."}
		check_empty(true)
		check_finished(true)
		seed_lots
		check_empty(false)
		check_finished(false)
		@g.harvest(:full_crop)
		check_empty(true)
		check_finished(true)
	end
	
	def teardown
		@g.close
	end
	
	private
	
	def set_gardener
    @g = Abundance.gardener(:rows => @rows, :init_timeout => 3) do
      Abundance.init_status(true,Process.pid)
      Abundance.grow do |seed|
				sprout = seed.sprout
				Array.new(100000,01).join
        seed.crop(true, "gardener1: #{sprout}")
      end      
    end
  end

	def seed_lots
		20.times do |num|
			@g.seed(num.to_s)
		end
	end
	
	def check_empty(bool)
		assert_equal(bool,@g.growth(:empty),"growth :empty does not return #{bool.to_s}")
	end
	
	def check_finished(bool)
		assert_equal(bool,@g.growth(:finished),"growth :finished does not return #{bool.to_s}")
	end
	
end