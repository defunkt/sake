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
    @options = {
      :args   => args,
      :target => detect_target(args),
      :source => detect_source(args)
    }
  end

  def invoke
    Action.invoke(@options)
  end

  def self.tasks
    sake_tasks
  end

  ##
  # Command line parsing
  def detect_target(args)
    args.detect { |arg| arg[/-|:\/\//].nil? }
  end

  def detect_source(args)
    args.detect { |arg| arg[/(\w+:\/\/)/] }
  end
end

Sake.new(ARGV).invoke if $0 == __FILE__
