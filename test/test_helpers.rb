require 'logger'
class GlobaLog < Logger
	$logger_args ||= Hash.new
	
	def GlobaLog.setup(def_out,def_level)
		Args.are(:log_output => def_out, :log_level => def_level)
		log = self.new(Args::log_output)
		log.level = Args::log_level
		return log
	end
	
	module Args
		
		def Args.are(args)
			$logger_args[:log_level] ||= args[:log_level].to_sym
			$logger_args[:log_output] ||= args[:log_output]
		end
		
		def Args::log_output
			$logger_args[:log_output]
		end

		def Args::log_level
			if $logger_args[:log_level].is_a?(Symbol)
				$logger_args[:log_level] = case $logger_args[:log_level]
				when :debug
					Logger::DEBUG
				when :info
					Logger::INFO
				when :warn
					Logger::WARN
				when :error
					Logger::ERROR
				when :fatal
					Logger::FATAL
				else
					Logger::UNKNOWN
				end
			end
		end
		
	end
	
	class OptHijacker < Hash
		require 'optparse'
		
		def initialize
			super()
			self[:log_level] = nil
			self[:log_output] = nil
			opts = OptionParser.new do |opts|
				opts.on('-L','--log-level [STRING]','sets the Test Log Level') do |string|
					self[:log_level] = string.to_sym
				end
				opts.on('-O','--log-output [I/O]','sets the Test Log output') do |io|
					self[:log_output] = io
				end
			end
			opts.parse!($keep_argv)
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
			$keep_argv ||= keep
		end

		self.keep_wanted_argv
		Args.are(self.new)

	end
	
end