class Sake
  class Version < Action
    Major = '0'
    Minor = '1'
    Tweak = '0'

    String = [ Major, Minor, Tweak ] * '.'

    def invoke
      puts "sake, version #{String}"
    end

    def invokable?
      @options[:args].include? '--version'
    end
  end
end
