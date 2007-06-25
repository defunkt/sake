class Sake
  class Action
    include Tasks

    def invoke
      raise "Override #invoke with your action's action."
    end

    def invokable?
      raise "Override #invokable? to return true if your action should execute."
    end

    ##
    # Override #halt_after_invokation? to return true or false depending on whether
    # you want execution to halt or not after this action is invoked.  By default,
    # actions are chained.
    def halt_after_invokation?
      false
    end

    @@actions = []

    def initialize(options = {})
      @options = options
    end

    def self.inherited(klass)
      @@actions << klass unless klass == Default
    end

    def self.invoke(options = {})
      raise "#invoke must be overriden" unless self == Action

      invoked = false

      @@actions.each do |action|
        action = action.new(options)

        next unless action.invokable?
        invoked = true

        action.invoke 

        return if action.halt_after_invokation?
      end

      Default.new(options).invoke unless invoked
    end

    ##
    # Task stuff
    def target_tasks
      file_tasks(@options[:target])
    end
  end
end
