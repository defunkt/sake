class Sake
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
      name = name.is_a?(Hash) ? name.keys.first : name
      @tasks << [ @namespace, name ].flatten * ':'
    end
  end
end
