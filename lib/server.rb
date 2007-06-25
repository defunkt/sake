require 'sake' unless defined? Sake

class Sake
  module Server
    extend self

    def start(args)
      require 'mongrel'

      if index = args.index('-p')
        port = args[index+1].to_i
      else
        port = 4567
      end

      handler   = handler_class
      daemonize = args.include? '-d'

      config = Mongrel::Configurator.new :host => "127.0.0.1" do
        listener(:port => port) { uri "/", :handler => handler.new }
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
      def process(request, response)
        uri    = request.params['PATH_INFO'].sub(/^\//, '')
        status = uri.empty? ? 200 : 404
        body   = status == 200 ? Store.to_ruby : 'Not Found' 

        response.start(status) do |headers, output|
          headers['Content-Type'] = 'text/plain'
          output.write body
        end
      end
    end
  end
end

Sake::Server.start(ARGV) if $0 == __FILE__
