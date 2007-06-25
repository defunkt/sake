class Sake
  class Action
    include Tasks

    @@actions = []

    def initialize(args, target, source)
      @args   = args
      @target = target
      @source = source
    end

    def self.inherited(klass)
      @@actions << klass
    end

    ##
    # Task stuff
    def target_tasks
      file_tasks(@target)
    end
  end
end
