require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
  s.name = 'abundance'
  s.version = '1.1.2'
  s.author = 'Louis-Philippe Perron'
  s.email = 'lp@spiralix.org'
  s.homepage = 'http://abundance.rubyforge.org/'
  s.rubyforge_project = 'Abundance'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Ruby Parallel Processing, Concurent Native Threads'
  s.files = FileList["{lib,test}/**/*"].exclude("doc").to_a
  s.require_path = "lib"
  s.test_file = "test/ts_abundance.rb"
  s.has_rdoc = true
end
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end
