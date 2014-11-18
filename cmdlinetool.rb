require 'byebug'

module Helpers
  def optdef(name, str, doc, ipt)
    { name => { string: str, doc: doc, input: ipt } }
  end
end

class CmdLineTool

  def initialize(opts={})
    @options = {
      help: { string: ["-h", "--help"], doc: "print this help", input: false }
    }.merge(opts.reduce({}, :merge))
    @argv = ARGV.dup
    @inputs = extract_inputs
  end

  def options
    @options
  end

  def inputs
    @inputs
  end

  def input
    inputs.first
  end

  def argindex( name )
    raise "Invalid option #{name}" if options[ name.to_sym ].nil?

    index = nil
    opts = options[ name.to_sym ][:string]

    if opts.is_a?( Array )
      opts = opts.each
      begin
        while index.nil? && o = opts.next
          index = @argv.index{ |a|  a == o }
        end
      rescue StopIteration
      end
    else
      index = @argv.index{ |a|  a == opts }
    end

    index
  end

  def arg( name )
    return nil unless index = argindex( name )
    raise "Option #{name} does not take any input" unless options[ name.to_sym ][:input]
    raise "Invalid input for option #{name}" unless (input = @argv[ index + 1 ]) && input[0] != '-'

    input
  end

  def option( arg_str )
    options.values.find{ |opt| opt[:string].include? arg_str }
  end

  def has_an_arg!
    if @argv.empty? || argindex( "help" )
      puts "Usage: ruby parse.rb [options] web_archive"
      options.each do |n, o|
        str = o[:string].is_a?( Array ) ? o[:string].join(', ') : o[:string]
        puts "  #{str}\t\t#{o[:doc]}"
      end
      abort
    end
  end

  def is_arg?( string )
    string[0] == '-'
  end

  def extract_inputs
    inputs = []
    @argv.each_with_index do |a, index|
      if is_arg?(a)
        next
      elsif opt = option(a) && !opt[:input]
        next
      else
        inputs << a
      end
    end

    inputs
  end
end
