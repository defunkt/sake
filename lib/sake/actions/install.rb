require 'fileutils'

class Sake
  class Install < Action
    def initalize(options = {})
      ensure_task_directory_exists
      super
    end

    def ensure_task_directory_exists
      FileUtils.mkdir task_directory unless File.exists? task_directory
    end

    def invoke
      if target_tasks.size != target_tasks.uniq.size
        puts "Can't install with duplicate tasks.  The following tasks are duped in #{@options[:target]}: "
        die with_indent(target_tasks & target_tasks)
      end

      target_tasks.each do |task|
        if sake_tasks.include?(task) 
          die "Doh! You already have an installed task named `#{task}'.  Please rename the task in #{@options[:target]} or #{task.sake_file}."
        end
      end

      FileUtils.cp @options[:target], fresh_task_path(@options[:target])
      puts "Installed these tasks: "
      puts with_indent(target_tasks)
    end
  end

  def with_indent(array)
    array.map { |task| "  #{task}" }
  end
end
