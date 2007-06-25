class Sake
  class Loader < Rake::DefaultLoader
    def load(file)
      super
    rescue Object => e
      puts "=> There was an error loading #{file}:"
      puts "   %s" % e.to_s
    end
  end

  class InvokeRake < Action
    def invoke 
      Rake.application = Rake::Application.new

      # TODO: love silence
      Rake.application.options.silent = true

      Rake.application.add_loader('rake', Loader.new)

      import *task_files
      Rake.application.run
    end
  end
end
