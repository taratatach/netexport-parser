require 'json'
require File.join(File.dirname(__FILE__), '.', 'cmdlinetool')

include Helpers

OPTIONS = [
  optdef(:verbose, ["-v", "--verbose"], "print generated json", false),
  optdef(:human, "--human", "generate human readable json file as well", false)
]

def run
  tty = CmdLineTool.new(OPTIONS)
  tty.has_an_arg!

  inputname = tty.input
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

  if argindex( "verbose" )
    puts "\nFile content:\n"
    puts JSON.pretty_generate( output, { space: " ", indent: "  " } )
  end
# rescue StandardError => e
#   puts "Error: #{e}"
end

run
