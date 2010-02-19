require 'net/http'
require 'cgi'
require 'uri'

begin
  require 'rubygems'
rescue LoadError
  nil
end

require 'hpricot'

module BestOfYouTube
  Host = "www.bestofyoutube.com"
  Debug = ENV['BESTOFYOUTUBE_DEBUG']
  Nothing = Object.new.freeze

  def part_url_for(part)
    "#{ Host }/index.php?part=#{ part }"
  end

  def top(part, options = {})
    result = []

    pages = options[:pages] || options['pages'] || 1
    page = 1

    request! do |http|
      loop do
        path = "/index.php?part=#{ part }&page=#{ page }"
        response = http.get(path)
        body = response.body

        doc = Hpricot(body)

        doc.search('object') do |object|
          object.search('param') do |param|
            value = param.attributes['value']
            if value =~ /youtube/
              dirname, basename = File.split(value)
              identifier = basename.sub(%r/&.*$/, '')
              result.push(youtube_watch_url_for(:identifier => identifier))
            end
          end
        end

        page += 1
        result!(result) if page >= pages
      end
    end

    result
  end

  def youtube_watch_url_for(options = {})
    identifier = options[:identifier] || options['identifier']
    "http://www.youtube.com/watch?v=#{ identifier }"
  end

  def request!(&block)
    error = nil

    result =
      catch(:result) do
        4.times do |i|
          begin
            http = Net::HTTP::new(Host)
            http.set_debug_output(STDERR) if Debug
            http.start do
              block.call(http) if block
            end
          rescue Object => e
            error = e
            sleep rand
          end
        end
        Nothing
      end

    # raise(error || 'unknown error') if result == Nothing
    return(result)
  end

  def result!(result)
    throw(:result, result)
  end

  extend(BestOfYouTube)
end

if $0 == __FILE__
  require 'pp'
  part = ARGV.shift || 'alltime'
  pages = Integer(ARGV.shift || 2)
  pp BestOfYouTube.top(part, :pages => pages)
end
