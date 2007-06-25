require 'sake' unless defined? Sake
require 'mongrel'

class Sake
  module Server
    extend self

    def start(args)
      if index = args.index('-p')
        port = args[index+1].to_i
      else
        port = 4567
      end
  
      daemoned = args.include? '-d'

      config = Mongrel::Configurator.new :host => "127.0.0.1" do
        daemonize(:cwd => '.', :log_file => 'sake.log') if daemoned
        listener(:port => port) { uri "/", :handler => Handler.new }
        run
      end

      puts "# Serving warm sake tasks on port #{port}..." unless daemoned
      config.join
    end

    class Handler < Mongrel::HttpHandler
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
