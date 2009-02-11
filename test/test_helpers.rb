require 'optparse'
class Arguments < Hash
	
	def initialize
		super()
		self[:log_level] = :info
		self[:log_output] = STDERR
		opts = OptionParser.new do |opts|
			opts.on('-L','--log-level [STRING]','sets the Test Log Level') do |string|
				self[:log_level] = string.to_sym
			end
			opts.on('-O','--log-output [I/O]','sets the Test Log output') do |io|
				self[:log_output] = io
			end
		end
		opts.parse!(@@argv)
	end
	
	def self.keep_wanted_argv
		args = Array.new(ARGV); ARGV.clear; keep = []
		wanted = ['-L', '--log-level', '-O', '--log-output']
		catch :finished do
			loop do
				throw :finished if args.empty?
				catch :found do
					wanted.each do |arg|
						if args[0] == arg
							2.times { keep << args.shift }
							throw :found
						end
					end
					ARGV << args.shift
				end
			end
		end
		return keep
	end
	
	@@argv = self.keep_wanted_argv
	
end

module LogHelper
	require 'logger'
	
	def setup_logger
		args = Arguments.new
		Abundance::log_level = args[:log_level]
		@log_test = Logger.new(args[:log_output])
		case args[:log_level]
		when :debug
			@log_test.level = Logger::DEBUG
		when :info
			@log_test.level = Logger::INFO
		when :warn
			@log_test.level = Logger::WARN
		when :error
			@log_test.level = Logger::ERROR
		when :fatal
			@log_test.level = Logger::FATAL
		else
			@log_test.level = Logger::UNKNOWN
		end
	end
	
end