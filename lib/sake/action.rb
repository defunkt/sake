class Sake
  class Action
    include Tasks

    @@children = []
    def self.children; @@children end

    def initialize(options = {})
      @options = options
    end

    def self.inherited(klass)
      @@children << klass
    end

    def self.choose_action(options = {})
      task = :invoke_rake

      if options[:target] && File.exists?(options[:target])
        task = :install
      end

      task
    end

    ##
    # Task stuff
    def target_tasks
      file_tasks(@options[:target])
    end
  end
end
