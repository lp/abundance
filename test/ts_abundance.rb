$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'test/unit'
require 'test/tc_high_api'
require 'test/tc_robustness'
require 'test/tc_multi_gardener'
require 'test/tc_burst'