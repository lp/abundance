# This class provides a mean to parallelize the execution of your program processes.
# Based on the low maintenance Gardener,Garden,Seed natural design pattern.
# 
# Its for:
# * running otherwise blocking loops in a non-blocking fashion
# * a simple abstraction for loopback communication with a forked execution
# * concurrent batch processing
# * scaling process intensive computations for SMP execution
# 
# And not:
# * a replacement for Thread.new invocations
# * a replacement for concurrent programming languages like Erlang
# 
# Its initial implementation uses:
# * pure ruby
# * standard forks as mean to parallel non-blocking execution
# * fast loopback sockets for process fork communication.
# * serialization friendly communication with process forks
# * a tier queuing fork, as a packet control middle man between process forks and the non-blocking process client
# * an elemental namespace: a process queue, named the Garden, with concurrent workers, named Rows, all this getting orchestrated by a Gardener.
# 
# ///////////////////////////////////////////////////////////////////////////////////////
# 
# Quick Start:
# 
# 1. gem install abundance
# 2. require abundance
# 3. use the Abundance.gardener method to define your forking process.  Its attached block IS THE FORK.  Its return value IS YOUR CLIENT INSTANCE.
# 4. Abundance.gardener has simple commodities:
# * infinite loop inside Abundance.grow method's block
# * initialisation before Abundance.grow invocation, just put it there... you can use Abundance.init_status if you need init confirmation from the forks, otherwise don't bother.
# * reader and sender for socket communication with your client.  seed.sprout reads, seed.crop sends.
# 5. use the client to communicate with forks: client.seed sends, client.harvest reads.
# 6. for detailed client docs: http://abundance.rubyforge.org/ruby-doc/classes/Gardener.html , and full docs: http://abundance.rubyforge.org/ruby-doc/
# 
# Author:: lp (mailto:lp@spiralix.org)
# Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
# 
# :title:Abundance
require 'globalog'
$log_abundance = GlobaLog.logger(STDERR,:warn)

class Abundance
	require File.join( File.dirname( File.expand_path(__FILE__)), 'garden')
	require File.join( File.dirname( File.expand_path(__FILE__)), 'gardener')
	require File.join( File.dirname( File.expand_path(__FILE__)), 'seed')
  
  # The +gardener+ class method initializes a gardener instance
  # with its garden supplied as a block.  The invocation block must include
  # the +grow+ class method and a preceeding optional initialisation section that may include and +init_status+ return message.
  # === Parameters
  # * :wheelbarrow = the socket size for the garden communication packets, in bytes, up to 8192, defaults to 124
  # * :rows = garden rows number, the number of concurent threads
  # * :init_timeout = allow to pause execution to allow for larger gardens to initialize
  # === Example
  #  gardener = Abundance.gardener( :wheelbarrow => 124, :rows => 2, :init_timeout => 2) do
  # 
  #   processor = SpecialProcess.new
  #   if processor.started_successfully?
  #     Abundance.init_status(true, processor.init_message)
  #   else
  #     Abundance.init_status(false, processor.init_message)
  #   end
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
  #  result1 = gardener.harvest(:one,id1)
  #  result2 = gardener.harvest(:one,id2)
  # 
  #  # with many more seeds over here
  # 
  #  gardener.close
  
  def Abundance.gardener(options={:wheelbarrow => 8192, :rows => 2, :init_timeout => 2},&gardener_block)
		$log_abundance.debug("Abundance.gardener") {"options: #{options.inspect}"}
		return Gardener.new(options,gardener_block)
  end
  
  # The +grow+ class method needs to be used inside the gardener invocation.
  # A seed instance is given each time, acting as getter/setter for your queued seed commands
  
  def Abundance.grow(&grow_block)
    until nil
			$log_abundance.debug("Abundance.grow") {"enter loop"}
      unless $seed.nil? || $seed.include?(:message)
				$log_abundance.debug("Abundance.grow") {"call grow block for seed: #{$seed.inspect}"}
        grow_block.call(Seed.new)
      end
      Thread.stop
    end
  end
  
  # The +init_status+ class method can be used inside the gardener invocation to return an initialisation status message.
  # The returned messages from all garden rows will then be accessible though the gardener's init_status instance method.
  # === Parameters
  # * _success_ = success of the initialisation, may be true or false
  # * _message_ = a ruby expression or object
  # === Example
  #   Abundance.init_status(true,'Initialisation Successfull!!!')
  def Abundance.init_status(success,message)
		$log_abundance.debug("Abundance.init_status") { "success: #{success.inspect} message: #{message.inspect}"}
    $init = {:id => Process.pid, :seed => 'init_status', :success => success, :message => message}
  end
  
end

