# This class provides a mean to parallelize the execution of your program processes.
# 
# Its caracteristics are:
# * concurent
# * non-blocking
# * simple
# * pure ruby
# * no dependency installation
# 
# It:
# * scales to multi core
# * is intended for batch processing or other parallel ready operations
# * can boost you program's performance
# 
# And not:
# * a replacement for Thread.new invocations
# * a replacement for Thread friendly programming languages like Erlang
# 
# 
# Based on Gardener,Garden,Seed natural design patern
# 
# While there should be no use for this kind of class in most programs, there are some occasions where processes
# cannot live inside serialized execution without blocking.  The built in threading model can save your execution in many occasions, but in many case green threading is not enough, or simply just won't work.
# For a nice explanation on the subject of ruby green threading, you can refer to: http://www.igvita.com/2008/11/13/concurrency-is-a-myth-in-ruby/
# 
# Abundance is by no mean intended to equal or compete with the tools mentionned in the article, its rather a different
# approach on the same problem.  I hope it will inspire some of you to hack out something that works even better,
# and hopefully, eventually this tool will become obsolete because Ruby will get concurency built in.
#  
# So, the approach here is really simple, you require abundance in your program.
# Then ask the Abundance.gardener class method to build you a garden built with a garden patch block you provide as part of the invocation.
# This garden patch block includes an initialization block, which may be empty,
# and the invocation of the Abundance.grow class method, the perpetual seed ready patch garden.
# It becomes the threaded looping object, growing concurently on garden patch row forks.
# 
# The gardener objected is then available to seeds and harvest the multiple garden patch row forks,
# allowing you to cultivate parallel garden rows where your seeds sprout till fruitful harvest time comes.
# 
# Author:: lp (mailto:lp@spiralix.org)
# Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
# 
# :title:Abundance

class Abundance
  require 'garden'
  require 'gardener'
  require 'seed'
  
  # The +gardener+ class method initializes a gardener instance
  # with its garden supplied as a block.  The invocation block must include
  # the +grow+ class method and a preceeding optional initialisation section.
  # === Parameters
  # * :seed_size = allowed seed size in bytes
  # * :rows = garden rows number, the number of concurent threads
  # * :init_timeout = allow to pause execution to allow for larger gardens to initialize
  # === Example
  #  gardener = Abundance.gardener( :block_size => 8192, :rows => 2, :init_timeout => 2) do
  # 
  #   processor = SpecialProcess.new
  # 
  #   Abundance.grow do |seed|
  #     command = seed.sprout 
  #     results = processor.parse(command) 
  #     seed.crop( true, results)  
  #   end
  #  
  #  end
  # 
  #  id1 = gardener.seed('command1')
  #  id2 = gardener.seed('command2')
  # 
  #  result1 = gardener.harvest(id1)
  #  result2 = gardener.harvest(id2)
  # 
  #  # with many more seeds over here
  # 
  #  gardener.close
  
  def Abundance.gardener(options={:seed_size => 8192, :rows => 2, :init_timeout => 2},&gardener_block)
    return Gardener.new(options,gardener_block)
  end
  
  # The +grow+ class method needs to be used inside the gardener invocation.
  # A seed instance is given each time, acting as getter/setter for your queued seed commands
  
  def Abundance.grow(&grow_block)
    loop do
      unless $seed.nil? || $seed.include?(:message) 
        grow_block.call(Seed.new)
      end
      Thread.stop
    end
  end
  
  # 
  # 
  def Abundance.init_status(success,message)
    $seed = {:id => Process.pid, :seed => 'init_status', :success => success, :message => message}
  end
  
end

