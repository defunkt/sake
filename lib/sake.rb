#!/usr/bin/env ruby

require 'rubygems'
require 'rake'

require 'sake/rake_faker'
require 'sake/hacks'
require 'sake/tasks'

require 'sake/action'

class Sake
  extend Tasks

  def initialize(args = [])
    @args   = args
    @target = detect_target(args)
    @source = detect_source(args)
  end

  def invoke
    require "sake/actions/#{action}"
    Sake.const_get(action.classify).new(@args, @target, @source).invoke
  end

  def self.tasks
    sake_tasks
  end

  ##
  # Command line parsing
  def action
    task = :invoke_rake

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

  def die(*message)
    puts(*message) || exit
  end
end

Sake.new(ARGV).invoke if $0 == __FILE__
