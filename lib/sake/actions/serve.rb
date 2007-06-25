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
      daemonize = @options[:args].include? '-d'

      config = Mongrel::Configurator.new :host => "127.0.0.1" do
        listener(:port => port) do 
          uri "/", :handler => handler.new 
          uri "/favicon.ico", :handler => Mongrel::Error404Handler.new('Not Found')
        end
        daemonize(:cwd => '.', :log_file => 'sake.log') if daemonize
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
        file   = request.params['PATH_INFO'].sub(/^\//, '')
        body   = file.empty? ? task_listing.to_yaml : task_file(file)
        status = body.nil? ? 404 : 200
        body ||= 'Not Found'

        response.start(status) do |headers, output|
          headers['Content-Type'] = 'text/plain'
          output.write body
        end
      end

      def task_listing
        task_files.inject({}) do |hash, file|
          hash.merge(File.basename(file, '.rake') => file_tasks(file))
        end
      end

      def task_file(file)
        File.read(task_path(file.sub('/','').squeeze('.'))) rescue nil
      end
    end
  end
end
