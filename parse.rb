require 'json'
require 'active_support/hash_with_indifferent_access'
require 'debugger'

OPTIONS = {
  verbose: { string: ["-v", "--verbose"].freeze, doc: "print generated json" },
  human: { string: "--human", doc: "generate human readable json file as well" },
  help: { string: ["-h", "--help"], doc: "print this help" }
}.freeze

def option?( name )
  raise "Invalid option #{name}" if OPTIONS[ name.to_sym ].nil?

  ARGV.any?{ |a| OPTIONS[ name.to_sym ][:string].include?( a ) }
end

def run
  if ARGV.empty? || option?( "help" )
    puts "Usage: ruby parse.rb [options] web_archive"
    OPTIONS.each do |n, o|
      str = o[:string].is_a?( Array ) ? o[:string].join(', ') : o[:string]
      puts "  #{str}\t\t#{o[:doc]}"
    end
    abort
  end

  inputname = ARGV[0]
  raise "File #{inputname} not found" unless File.file?( inputname )

  puts "Parsing #{inputname}..."
  inputfile = File.read( inputname )
  puts "  Cleaning up data..."
  inputfile = inputfile[12..-3]
  puts "  Done!"
  hash = JSON.parse(inputfile, { symbolize_names: true })
  #hash = HashWithIndifferentAccess.new( hash )
  puts "Done!" # Parsing

  puts "Extracting data..."
  output = {}

  puts "  Fetching pages..."
  hash[:log][:pages].each do |page|
    output[ page[:id] ] = {
      url: nil,
      timings: [
        contentLoad: page[:pageTimings][:onContentLoad],
        completeLoad: page[:pageTimings][:onLoad]
      ],
      parts: []
    }
  end
  puts "  Done!"

  puts "  Fetching pages parts..."
  hash[:log][:entries].each_with_index do |entry, index|
    cacheControl = entry[:response][:headers].select{ |h| h[:name] == "Cache-Control" }
    cacheControl = cacheControl.any? ? cacheControl.first[:value] : nil
    rackCacheHit = entry[:response][:headers].select{ |h| h[:name] == "X-Rack-Cache" }
    rackCacheHit = rackCacheHit.any? ? rackCacheHit.first[:value] : nil

    output[ entry[:pageref] ][:url] = entry[:request][:url] if index == 0
    output[ entry[:pageref] ][:parts] << {
      dateTime: entry[:startedDateTime],
      loadTime: entry[:time],
      url: entry[:request][:url],
      status: entry[:response][:status],
      cacheControl: cacheControl,
      rackCacheHit: rackCacheHit,
      contentSize: entry[:response][:content][:size],
      headersSize: entry[:response][:headersSize],
      bodySize: entry[:response][:bodySize],
      loadTimeBreakout: entry[:timings]
    }
  end
  puts "  Done!"

  puts "Done!" # Extracting

  outputname = inputname.split('.').first + '.json'
  puts "Saving data to #{outputname}..."
  outputfile = File.open(outputname, "w")
  outputfile.write(output.to_json)
  puts "Done!"

  if option?( "verbose" )
    puts "\nFile content:\n"
    puts JSON.pretty_generate( output, { space: " ", indent: "  " } )
  end
rescue StandardError => e
  puts "Error: #{e}"
end

run
