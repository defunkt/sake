##
# Sake.  Best served warm.
#
# >> Chris Wanstrath
# => chris@ozmm.org

require 'rubygems'
require 'rake'
require 'fileutils'
require 'open-uri'
begin
  gem 'ParseTree', '=2.1.1'
  require 'parse_tree'
  gem 'ruby2ruby', '=1.1.8'
  require 'ruby2ruby'
rescue LoadError
  puts "# Sake requires the ruby2ruby gem and Ruby 1.8.6."
  exit
end
require File.dirname(__FILE__) + '/help'
require File.dirname(__FILE__) + '/pastie'

##
# Show all Sake tasks (but no local Rake tasks), optionally only those matching a pattern.
#   $ sake -T
#   $ sake -T db
#
# Show tasks in a Rakefile, optionally only those matching a pattern.
#   $ sake -T file.rake
#   $ sake -T file.rake db
#
# Install tasks from a Rakefile, optionally specifying specific tasks.
#   $ sake -i Rakefile
#   $ sake -i Rakefile db:remigrate
#   $ sake -i Rakefile db:remigrate routes
#
# Examine the source of a Rake task.
#   $ sake -e routes
# 
# You can also examine the source of a task not yet installed. 
#   $ sake -e Rakefile db:remigrate
#
# Uninstall an installed task.
#   $ sake -u db:remigrate
#
# Stores the source of a task into a pastie (http://pastie.caboo.se).
# Returns the url of the pastie to stdout.
#   $ sake -P routes
#
# Can be passed one or more tasks.
#
# Invoke a Sake task.
#   $ sake <taskname>
#
# Some Sake tasks may depend on tasks which exist only locally.
#
# For instance, you may have a db:version sake task which depends
# on the 'environment' Rake task.  The 'environment' Rake task is one
# defined by Rails to load its environment.  This db:version task will
# work when your current directory is within a Rails app because
# Sake knows how to find Rake tasks.  This task will not work,
# however, in any other directory (unless a task named 'environment' 
# indeed exists).
#
# Sake can also serve its tasks over a network by launching a Mongrel handler.
# Pass the -S switch to start Sake in server mode.
#
#   $ sake -S
#
# You can, of course, specify a port.
#   $ sake -S -p 1111
#
# You can also daemonize your server for long term serving fun.
#   $ sake -S -d
#
class Sake
  module Version #:nodoc:
    Major  = '1'
    Minor  = '0'
    Tweak  = '14'
    String = [ Major, Minor, Tweak ].join('.')
  end

  ##
  # The `application' class, this is basically the controller
  # which decides what to do then executes.
  def initialize(args)
    @args = args
    Rake.application
    Rake.application.options.silent = true
  end

  ##
  # This method figures out what to do and does it.
  # Basically a big switch.  Note the seemingly random
  # return statements: return if you don't want run_rake invoked.
  # Some actions do want it invoked, however, so they don't return
  # (like version, which prints a Sake version then trusts Rake to do
  # likewise).
  def run
    ##
    # Show Sake tasks in the store or in a file, optionally searching for a pattern.
    # $ sake -T 
    # $ sake -T db
    # $ sake -T file.rake
    # $ sake -T file.rake db
    # Show all Sake tasks in the store or in a file, optionally searching for a pattern.
    # $ sake -Tv
    # $ sake -Tv db
    # $ sake -Tv file.rake
    # $ sake -Tv file.rake db
    if (index = @args.index('-T') || @args.index('-Tv')) || @args.empty?
      display_hidden = true if @args.index('-Tv') 
      begin
        tasks   = TasksFile.parse(@args[index + 1]).tasks
        pattern = @args[index + 2]
      rescue
        tasks   = Store.tasks.sort
        pattern = index ? @args[index + 1] : nil
      end
      return show_tasks(tasks, pattern, display_hidden)

    ##
    # Install a Rakefile or a single Rake task
    # $ sake -i Rakefile
    # $ sake -i Rakefile db:migrate
    elsif index = @args.index('-i')
      return install(index)

    ##
    # Uninstall one or more Rake tasks from the Sake store.
    elsif index = @args.index('-u')
      return uninstall(index)

    ##
    # Examine a Rake task
    #   $ sake -e routes
    #   $ sake -e Rakefile db:remigrate
    elsif index = @args.index('-e')
      die examine(index)

    ##
    # Save one or more tasks to Pastie (http://pastie.caboos.se) 
    # then return the new Pastie's url 
    #   $ sake -P routes
    #   $ sake -P Rakefile db:remigrate
    elsif index = @args.index('-P')
      die Pastie.paste(examine(index))

    ##
    # Start a Mongrel handler which will serve local Rake tasks
    # to anyone who wants them.
    #
    # $ sake -S
    #
    # Set a port
    # $ sake -S -p 1111
    #
    # Daemonize
    # $ sake -S -d
    elsif @args.include? '-S'
      return serve_tasks

    ##
    # Prints Sake and Rake versions.
    elsif @args.include? '--version'
      version

    ##
    # Prints out the help screen.
    elsif @args.include? '-h' or @args.include? '--help'
      return Help.display
    end

    ##
    # Runs Rake proper, including our ~/.sake tasks.
    run_rake
  end

  private

  def show_tasks(tasks = [], pattern = nil, display_hidden = nil)
    Rake.application.show(tasks, pattern, display_hidden)
  end

  def install(index)
    die "# I need a Rakefile." unless file = @args[index+1]

    tasks = TasksFile.parse(file).tasks

    # We may want to install a specific task
    unless (target_tasks = @args[index + 2..-1]).empty?
      tasks = tasks.select { |task| target_tasks.include? task.name }
    end

    # No duplicates.
    tasks.each do |task|
      if Store.has_task? task
        puts "# Task `#{task}' already exists in #{Store.path}"
      else
        puts "# Installing task `#{task}'"
        Store.add_task task
      end
    end

    # Commit.
    Store.save!
  end

  def uninstall(index)
    die "# -u option needs one or more installed tasks" if (tasks = @args[index+1..-1]).empty?

    tasks.each do |name|
      if task = Store.tasks[name]
        puts "# Uninstalling `#{task}'.  Here it is, for reference:", task.to_ruby, ''
        Store.remove_task(task)
      else
        puts "# You don't have task `#{name}' installed.", ''
      end
    end

    Store.save!
  end

  ##
  # There is a lot of guesswork inside this method.  Sorry.
  def examine(index)
    # Can be -e file task or -e task, which defaults to Store.path
    if @args[index + 2]
      file = @args[index + 1]
      task = @args[index + 2]
    else
      task = @args[index + 1]
    end

    # They didn't pass any args in, so just show the ~/.sake file
    unless task
      return Store.tasks.to_ruby
    end

    # Try to find the task we think they asked for.
    tasks = file ? TasksFile.parse(file).tasks : Store.tasks

    if tasks[task]
      return tasks[task].to_ruby 
    end

    # Didn't find the task.  See if it's a file and, if so, spit
    # it out.
    unless (tasks = TasksFile.parse(task).tasks).empty?
      return tasks.to_ruby 
    end

    # Failure.  On all counts.
    error = "# Can't find task (or file) `#{task}'"
    error << " in #{file}" if file
    die error
  end

  def serve_tasks
    require File.dirname(__FILE__) + '/server'
    Server.start(@args)
  end

  def version
    puts "sake, version #{Version::String}"
  end

  def run_rake
    import Sake::Store.path
    Rake.application.run
  end

  ##
  # Lets us do:
  #   tasks = TasksFile.parse('Rakefile').tasks
  #   task  = tasks['db:remigrate']
  class TasksArray < Array
    ##
    # Accepts a task name or index.
    def [](name_or_index)
      if name_or_index.is_a? String
        detect { |task| task.name == name_or_index }
      else
        super
      end
    end

    ##
    # The source of all these tasks.
    def to_ruby
      map { |task| task.to_ruby }.join("\n")
    end
  end

  ##
  # This class represents a Rake task file, in the traditional sense.
  # It takes on parameter: the path to a Rakefile.  When instantiated,
  # it will read the file and parse out the rake tasks, storing them in
  # a 'tasks' array.  This array can be accessed directly:
  #
  #   file = Sake::TasksFile.parse('Rakefile')
  #   puts file.tasks.inspect
  #
  # The parse method also works with remote files, as its implementation 
  # uses open-uri's open().
  #
  #   Sake::TasksFile.parse('Rakefile')
  #   Sake::TasksFile.parse('http://errtheblog.com/code/errake')
  class TasksFile
    attr_reader :tasks

    ##
    # The idea here is that we may be sucking in Rakefiles from an untrusted
    # source.  While we're happy to let the user audit the code of any Rake
    # task before running it, we'd rather not be responsible for executing a
    # `rm -rf` in the Rakefile itself.  To ensure this, we need to set a 
    # safelevel before parsing the Rakefile in question.
    def self.parse(file)
      body = open(file).read

      instance = new
      Thread.new { instance.instance_eval "$SAFE = 3\n#{body}" }.join
      instance
      
    rescue Errno::ENOENT
      STDERR.puts "Error: The file '#{file}' doesn't exist!"
      exit 1
    rescue OpenURI::HTTPError
      STDERR.puts "Error: '#{file}' not found! (OpenURI::HTTPError)"
      exit 1
    end

    def initialize
      @namespace = []
      @tasks     = TasksArray.new
      @comment   = nil
    end

    ##
    # We fake out an approximation of the Rake DSL in order to build
    # our tasks array.
    private

    ##
    # Set a namespace for the duration of the block.  Namespaces can be 
    # nested.
    def namespace(name)
      @namespace << name
      yield
      @namespace.delete name
    end

    ##
    # Describe the following task.
    def desc(comment)
      @comment = comment
    end

    ## 
    # Define a task and any dependencies it may have.
    def task(name, &block)
      # If we're passed a hash, we know it has one key (the name of
      # the task) pointing to a single or multiple dependencies. 
      if name.is_a? Hash
        deps = name.values.first 
        name = name.keys.first
      end

      # Our namespace is really just a convenience method.  Essentially,
      # a namespace is just part of the task name.
      name = [ @namespace, name ].flatten * ':'

      # Sake's version of a rake task
      task = Task.new(name, deps, @comment, &block)

      @tasks << task

      # We sucked up the last 'desc' declaration if it existed, so now clear
      # it -- we don't want tasks without a description given one.
      @comment = nil
    end

    public

    ##
    # Call to_ruby on all our tasks and return a concat'd string of them.
    def to_ruby
      @tasks.to_ruby
    end

    ##
    # Add tasks to this TasksFile.  Can accept another TasksFile object or
    # an array of Task objects.
    def add_tasks(tasks)
      Array(tasks.is_a?(TasksFile) ? tasks.tasks : tasks).each do |task|
        add_task task
      end
    end

    ##
    # Single task version of add_tasks
    def add_task(task)
      @tasks << task
    end

    ##
    # Does this task exist?
    def has_task?(task)
      @tasks.map { |t| t.to_s }.include? task.to_s
    end

    ##
    # Hunt for and remove a particular task.
    def remove_task(target_task)
      @tasks.reject! { |task| task.name == target_task.name }
    end
  end

  ##
  # This is Sake's version of a Rake task.  Please handle with care.
  class Task
    attr_reader :name, :comment

    def initialize(name, deps = nil, comment = nil, &block)
      @name    = name
      @comment = comment
      @deps    = Array(deps)
      @body    = block
    end

    ##
    # Turn ourselves back into Rake task plaintext.
    def to_ruby
      out = ''
      out << "desc '#{@comment.gsub("'", "\\\\'")}'\n" if @comment
      out << "task '#{@name}'"

      if @deps.any?
        deps = @deps.map { |dep| "'#{dep}'" }.join(', ')
        out << " => [ #{deps} ]" 
      end

      out << " do\n"
      
      # get rid of the proc { / } lines
      out << @body.to_ruby.split("\n")[1...-1].join("\n") rescue nil

      out << "\nend\n"
    end

    ##
    # String-ish duck typing, sorting based on Task names
    def <=>(other)
      to_s <=> other.to_s
    end

    ##
    # The task name
    def to_s; @name end

    ##
    # Basically to_s.inspect
    def inspect; @name.inspect end
  end

  ##
  # The store is, as of writing, a single Rakefile: ~/.sake
  # When we add new tasks, we just re-build this file.  Over
  # and over.
  module Store
    extend self

    ##
    # Everything we can't catch gets sent to our tasks_file.
    # Common examples are #tasks or #add_task.
    def method_missing(*args, &block)
      tasks_file.send(*args, &block)
    end

    ##
    # A TaskFile object of our Store
    def tasks_file
      @tasks_file ||= TasksFile.parse(path)
    end

    ##
    # The platform-aware path to the Store
    def path
      path = if PLATFORM =~ /win32/
        win32_path
      else
        File.join(File.expand_path('~'), '.sake')
      end
      FileUtils.touch(path) unless path.is_file?
      path
    end

    def win32_path #:nodoc:
      unless File.exists?(win32home = ENV['HOMEDRIVE'] + ENV['HOMEPATH'])
        puts "# No HOMEDRIVE or HOMEPATH environment variable.",  
             "# Sake needs to know where it should save Rake tasks!"
      else
        File.join(win32home, 'Sakefile')
      end
    end

    ##
    # Wrote our current tasks_file to disk, overwriting the current Store.
    def save!
      File.open(path, 'w') do |file|
        file.puts tasks_file.to_ruby
      end
    end
  end
end

module Rake # :nodoc: all
  class Application
    ##
    # Show the tasks as 'sake' tasks.
    def printf(*args)
      args[0].sub!('rake', 'sake') if args[0].is_a? String
      super
    end

    ##
    # Show tasks that don't have comments'
    def display_tasks_and_comments(tasks = nil, pattern = nil, display_hidden = nil)
      tasks ||= self.tasks

      if pattern ||= options.show_task_pattern
        tasks = tasks.select { |t| t.name[pattern] || t.comment.to_s[pattern] }
      end

      width = tasks.collect { |t| t.name.length }.max

      tasks.each do |t|
        comment = "   # #{t.comment}" if t.comment
        if display_hidden
          printf "sake %-#{width}s#{comment}\n", t.name
        else
          printf "sake %-#{width}s#{comment}\n", t.name if t.name && t.comment
        end
      end
    end
    alias_method :show, :display_tasks_and_comments

    ##
    # Run Sake even if no Rakefile exists in the current directory.
    alias_method :sake_original_have_rakefile, :have_rakefile
    def have_rakefile(*args)
      @rakefile ||= ''
      sake_original_have_rakefile(*args) || true
    end
  end
end

##
# Hacks which give us "Rakefile".is_file? 
class String # :nodoc: 
  def is_file?
    File.exists? self
  end
end

class Nil # :nodoc: 
  def is_file?
    false
  end

  # under the evil
  def method_missing(*args, &block)
    super
  end
end

def die(*message) # :nodoc: 
  puts message 
  exit
end

Sake.new(ARGV).run if $0 == __FILE__
