require 'logger'
class LogEngine < Logger
	
	def LogEngine.setup
		if $logger_args[:log_level].is_a?(Symbol)
			$logger_args[:log_level] = case $logger_args[:log_level]
			when :debug
				DEBUG
			when :info
				INFO
			when :warn
				WARN
			when :error
				ERROR
			when :fatal
				FATAL
			else
				UNKNOWN
			end
		end
		log = self.new($logger_args[:log_output])
		log.level = $logger_args[:log_level]
		return log
	end
	
	class Arguments < Hash
		require 'optparse'
		
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
			opts.parse!($logger_argv)
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

		$logger_argv ||= self.keep_wanted_argv
		$logger_args ||= self.new

	end
	
end