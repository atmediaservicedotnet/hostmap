require 'open-uri'
require 'set'

#
# Check against GPG keyserver.
#
PlugMan.define :gpgbydomain do
  author "Alessandro Tanasi"
  version "0.2.1"
  extends({ :main => [:domain] })
  requires []
  extension_points []
  params({ :description => "Check against GPG keyserver" })

  def run(domain, opts = {})
    @hosts = Set.new

    begin
      page = open("http://pgp.mit.edu:11371/pks/lookup?search=#{domain}&op=index").read
    rescue
      return @hosts
    end

    page.force_encoding("ISO-8859-1").encode("utf-8", replace: nil).scan(/&lt;.*@(.*?)&gt;<\/a>/).each do |url|
      @hosts << { :hostname => url[0].to_s }
    end

    return @hosts
  end

  def timeout
    return @hosts
  end
end
