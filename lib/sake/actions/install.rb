require 'fileutils'

class Sake
  class Install < Action
    def initalize(*args)
      ensure_task_directory_exists
      super
    end

    def ensure_task_directory_exists
      FileUtils.mkdir task_directory unless File.exists? task_directory
    end

    def invoke
      if target_tasks.size != target_tasks.uniq.size
        puts "Can't install with duplicate tasks.  The following tasks are duped in #{@target}: "
        die with_indent(target_tasks & target_tasks)
      end

      target_tasks.each do |task|
        if sake_tasks.include?(task) 
          die "Doh! You already have an installed task named `#{task}'.  Please rename the task in #{@target} or #{task.sake_file}."
        end
      end

      FileUtils.cp @target, fresh_task_path(@target)
      puts "Installed these tasks: "
      puts with_indent(target_tasks)
    end
  end

  def with_indent(array)
    array.map { |task| "  #{task}" }
  end
end
