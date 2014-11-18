require 'json'
require File.join(File.dirname(__FILE__), '.', 'cmdlinetool')
require File.join(File.dirname(__FILE__), '.', 'harp')

include Helpers

OPTIONS = [
  optdef(:verbose, ["-v", "--verbose"], "print generated json", false),
  optdef(:human, "--human", "print result instead of writing to a file", false),
  optdef(:csv, "--csv", "generate CSV instead of JSON", false)
]

def run
  tty = CmdLineTool.new(OPTIONS)
  tty.has_an_arg!

  inputname = tty.input
  raise "File #{inputname} not found" unless File.file?( inputname )

  export = Harp.new( inputname )

  if tty.argindex( "human" )
    if tty.argindex( "csv" )
      puts export.to_csv
    else
      puts JSON.pretty_generate( export.data, { space: " ", indent: "  " } )
    end
  else
    if tty.argindex( "csv" )
      output = export.to_csv
      extension = "csv"
    else
      output = export.to_json
      extension = "json"
    end

    outputname = inputname.split('/').last.split('.').first + ".#{extension}"
    outputfile = File.open(outputname, "w")
    outputfile.write( output )
  end

  if tty.argindex( "verbose" )
    puts "File content:\n"
    puts JSON.pretty_generate( export.data, { space: " ", indent: "  " } )
  end
rescue StandardError => e
  puts "Error: #{e}"
end

run
