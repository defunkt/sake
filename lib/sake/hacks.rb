##
# Duck punching.
module Rake
  module TaskManager
    alias_method :sake_actual_get, :[]

    def [](task_name, scopes = nil)
      sake_actual_get(task_name, scopes)
    rescue RuntimeError => error
      task = error.to_s.scan(/'(\S+)'/).first
      puts "Don't know how to build task `#{task}'"
      exit
    end
  end

  class Application
    def printf(*args)
      args[0].sub!('rake', 'sake') if args[0].is_a? String
      super
    end

    def display_tasks_and_comments
      tasks = self.tasks

      if pattern = options.show_task_pattern
        tasks = tasks.select { |t| t.name[pattern] || t.comment.to_s[pattern] }
      end

      sake_tasks = Sake.tasks
      tasks      = tasks.select { |t| sake_tasks.include? t.name }

      width = tasks.collect { |t| t.name.length }.max

      tasks.each do |t|
        comment = "   # #{t.comment}" if t.comment
        printf "sake %-#{width}s#{comment}\n", t.name
      end
    end
  end
end

class String
  def classify
    tr(' ', '_').split('_').map { |s| s.capitalize }.join
  end unless respond_to? :classify
end 

class Symbol
  def classify
    to_s.classify
  end
end

def die(*message)
  puts(*message) || exit
end
