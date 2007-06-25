require 'rubygems'
require 'rake'

version = '0.1.0'

begin
  require 'echoe'

  Echoe.new('sake', version) do |p|
    p.rubyforge_name = 'sake'
    p.summary = "sake tastes great and helps maintain system-level Rake files"
    p.description = "sake tastes great and helps maintain system-level Rake files"
    p.url = "http://errtheblog.com/"
    p.author = 'Chris Wanstrath'
    p.email = "chris@ozmm.org"
    p.test_globs = 'test/*_test.rb' 
  end

rescue LoadError => boom
  puts "You are missing a dependency required for meta-operations on this gem."
  puts "#{boom.to_s.capitalize}."
end
