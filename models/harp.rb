require 'json'

class Harp < WebArchive
  def initialize( filename )
    super( filename )

    @file = File.read( filename )[12..-3]
  end
end
