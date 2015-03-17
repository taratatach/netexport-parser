class Har < WebArchive
  def initialize( filename )
    super( filename )

    @file = File.read( filename )
  end
end
