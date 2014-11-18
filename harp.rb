require 'json'
require 'csv'

class Harp
  def initialize( filename )
    @filename = filename
    @file = File.read( filename )[12..-3]
    @data = parse
  end

  def data
    @data
  end

  def parse
    hash = JSON.parse(@file, { symbolize_names: true })

    output = {}
    hash[:log][:pages].each do |page|
      output = {
        url: nil,
        timings: [
          contentLoad: page[:pageTimings][:onContentLoad],
          completeLoad: page[:pageTimings][:onLoad]
        ],
        jsSize: 0,
        cssSize: 0,
        imagesSize: 0,
        vendorSize: 0,
        parts: []
      }
    end

    hash[:log][:entries].each_with_index do |entry, index|
      cacheControl = entry[:response][:headers].select{ |h| h[:name] == "Cache-Control" }
      cacheControl = cacheControl.any? ? cacheControl.first[:value] : nil
      rackCacheHit = entry[:response][:headers].select{ |h| h[:name] == "X-Rack-Cache" }
      rackCacheHit = rackCacheHit.any? ? rackCacheHit.first[:value] : nil

      output[:url] = entry[:request][:url] if index == 0
      output[:vendorSize] += entry[:response][:content][:size] if is_vendor?( entry )
      output[:jsSize] += entry[:response][:content][:size] if is_js?( entry )
      output[:cssSize] += entry[:response][:content][:size] if is_css?( entry )
      output[:imagesSize] += entry[:response][:content][:size] if is_image?( entry )
      output[:parts] << {
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

    output
  end

  def is_vendor?( entry )
    (/coverhound\.com/ =~ entry[:request][:url]).nil?
  end

  def is_js?( entry )
    /\.js/ =~ entry[:request][:url]
  end

  def is_css?( entry )
    /\.css/ =~ entry[:request][:url]
  end

  def is_image?( entry )
    /\.(png|gif|jpg|jpeg)/ =~ entry[:request][:url]
  end

  def to_json
    data.to_json
  end

  def to_csv
    url = data[:url].split('.com/').last
    [url, "", "", data[:jsSize], data[:cssSize], data[:imagesSize], data[:vendorSize]].to_csv
  end
end
