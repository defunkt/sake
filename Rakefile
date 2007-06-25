require 'rubygems'
require 'rake'

require 'lib/sake' unless defined? Sake

begin
  require 'echoe'

  Echoe.new('sake', Sake::Version::String) do |p|
    p.rubyforge_name = 'sake'
    p.summary = "Sake tastes great and helps maintain system-level Rake files."
    p.description = "Sake tastes great and helps maintain system-level Rake files."
    p.url = "http://errtheblog.com/"
    p.author = 'Chris Wanstrath'
    p.email = "chris@ozmm.org"
    p.test_globs = 'test/*_test.rb' 
  end

rescue LoadError => boom
  puts "You are missing a dependency required for meta-operations on this gem."
  puts "#{boom.to_s.capitalize}."
end
