#!/usr/bin/env ruby

require 'rubygems'
#require 'rake-0.7.2/lib/rake'
require 'rake'
require 'fileutils'

class Sake
  def initialize(args = [])
    ensure_task_directory_exists
    @args   = args
    @target = detect_target(args)
    @source = detect_source(args)
  end

  def run
    send action
  end

  ##
  # Actions
  def install
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

  def with_indent(array)
    array.map { |task| "  #{task}" }
  end

  ##
  # Command line parsing
  def action
    task = :run_rake

    if @target && File.exists?(@target)
      task = :install
    end

    task
  end

  def detect_target(args)
    args.detect { |arg| arg[/-|:\/\//].nil? }
  end

  def detect_source(args)
    args.detect { |arg| arg[/(\w+:\/\/)/] }
  end

  ##
  # Do it.
  def run_rake
    Rake.application = Rake::Application.new

    # TODO: love silence
    Rake.application.options.silent = true

    import *task_files
    Rake.application.run
  end

  ##
  # Task stuff
  def target_tasks
    file_tasks(@target)
  end

  def sake_tasks
    task_files.map { |file| file_tasks(file) }.flatten
  end

  def file_tasks(file)
    RakeFaker.new(file).tasks
  end

  def task_files 
    Dir["#{task_directory}/*.rake"]
  end

  def sake_file(string)
    task_files.detect do |file|
      RakeFaker.new(file).tasks.include? string
    end
  end

  def task_directory
    File.join(File.expand_path('~'), '.sake')
  end

  def ensure_task_directory_exists
    FileUtils.mkdir task_directory unless File.exists? task_directory
  end

  def task_path(file)
    file = "#{file}.rake" unless file[/.rake$/]
    File.join(task_directory, file)
  end

  def fresh_task_path(file)
    file = file[/\.rake$/] ? file : "#{file}.rake"

    if File.exists? task = task_path(file)
      file_parts = file.split('.')
      file = [ file_parts[0...-1], Time.now.to_i, 'rake' ].flatten
      task_path(file * '.')
    else
      task 
    end
  end

  def die(*message)
    puts(*message) || exit
  end

  class RakeFaker
    attr_reader :tasks

    def initialize(file)
      @namespace = []
      @tasks = []
      instance_eval File.read(file)
    end

    def namespace(name)
      @namespace << name
      yield
      @namespace.delete name
    end

    def task(name)
      @tasks << [ @namespace, name ].flatten * ':'
    end
  end
end

class String
  def sake_file
    Sake.new.sake_file(self)
  end
end

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
      if pattern = options.show_task_pattern
        tasks = self.tasks.select { |t| t.name[pattern] || t.comment.to_s[pattern] }
      end

      width = tasks.collect { |t| t.name.length }.max

      tasks.each do |t|
        comment = "   # #{t.comment}" if t.comment
        printf "sake %-#{width}s#{comment}\n", t.name
      end
    end

    def have_rakefile
      @rakefile = ''
      true
    end
  end
end

Sake.new(ARGV).run if $0 == __FILE__
