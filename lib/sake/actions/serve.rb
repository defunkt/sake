class Sake
  class Serve < Action
    def invokable? 
      @options[:args].include? '-S'
    end

    def invoke
      require 'mongrel'

      if index = @options[:args].index('-p')
        port = @options[:args][index+1].to_i
      else
        port = 4567
      end

      directory = sake_directory
      handler   = handler_class

      config = Mongrel::Configurator.new :host => "127.0.0.1" do
        listener(:port => port) { uri "/", :handler => handler.new }
        run
      end

      puts "=> Serving warm sake tasks on port #{port}..."
      config.join
    end

    # We don't want to require mongrel if you're not gonna use
    # it, y'know?
    def handler_class
      Class.new(Mongrel::HttpHandler) { include Handler }
    end

    module Handler 
      include Tasks

      def process(request, response)
        response.start(200) do |headers, output|
          headers['Content-Type'] = 'text/plain'
          task = request.params['PATH_INFO'].sub(/^\//, '')
          output.write task.empty? ? task_listing.to_yaml : task_listing[task]
        end
      end

      def task_listing
        task_files.inject({}) do |hash, file|
          hash.merge(File.basename(file, '.rake') => File.read(file))
        end
      end
    end
  end
end
