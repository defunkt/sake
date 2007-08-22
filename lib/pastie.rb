require 'tempfile'

class Pastie #:nodoc: all
  PASTE_URL = ENV['SAKE_PASTIE_URL'] || ENV['PASTIE_URL'] || 'http://pastie.caboo.se/pastes/create'

  def self.paste(text)
    text_file = Tempfile.open('w+')
    text_file << text
    text_file.flush

    cmd = <<-EOS
    curl #{PASTE_URL} \
    -s -L -o /dev/null -w "%{url_effective}" \
    -H "Expect:" \
    -F "paste[parser]=ruby" \
    -F "paste[restricted]=0" \
    -F "paste[authorization]=burger" \
    -F "paste[body]=<#{text_file.path}" \
    -F "key=" \
    -F "x=27" \
    -F "y=27"
    EOS
    
    out = %x{
      #{cmd}
    }
  
    text_file.close(true)
    out
  end
end
