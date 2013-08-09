require 'set'
require 'socket'
require 'timeout'

begin
require 'net/https'
rescue Exception
  $LOG.warn "Missing library OpenSSL, please install libopenssl-ruby."
end


#
# Simple work around to avoid messagges "warning: peer certificate won't be verified in this SSL session".
#
class Net::HTTP

  alias_method :old_initialize, :initialize

  def initialize(*args)
    old_initialize(*args)
    begin
      @ssl_context = OpenSSL::SSL::SSLContext.new
      @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
    rescue
      @ssl_context = nil
    end
  end
end

#
# Check the X.509 certificate from the web server.
#
PlugMan.define :sslcertbyaddress do
  author "Alessandro Tanasi"
  version "0.2.1"
  extends({ :main => [:ip] })
  requires []
  extension_points []
  params({ :description => "Check the X.509 certificate from the web server." })

  def check_open_port?(ip,port) 
  	begin
    	Timeout::timeout(1) do
    	  begin
        	s = TCPSocket.new(ip, port)
        	s.close
        	return true
      	rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        	return false
      	end
   	 end
  	rescue Timeout::Error
  	end

  	return false

  end

  def run(ip, opts = {})
    @hosts = Set.new

    # Configuration check
    if opts['onlypassive']
      $LOG.warn "Skipping SSL because only passive checks are enabled"
      return @hosts
    end

    opts['httpports'].to_s.split(",").each do |port|
      begin

		if !check_open_port?(ip,port)
			$LOG.debug("Port #{i} unreachable [:sslcertbyaddress]")
			next
		end
        http = Net::HTTP.new(ip, port.to_i)
        http.use_ssl = true
		http.verify_mode = OpenSSL::SSL::VERIFY_NONE
		http.read_timeout = 5

        @cns = []
      
        http.start() do |conn|
          cert = OpenSSL::X509::Certificate.new conn.peer_cert
		  $LOG.debug("SSL connection performed")
          # Get data from issuer CN field
          cert.issuer.to_a.each{|oid, value|
            @cns << value if oid == "CN"
          }
          # Get data from subject CN field
          cert.subject.to_a.each{|oid, value|
            @cns << value if oid == "CN"
          }
          cert.extensions.each { |ext|
            # Fucking hack because OpenSSL::X509::Extension documentaion is missing
            if ext.to_s =~ /^subjectAltName =/
              ext.to_s.gsub(/^subjectAltName = /, '').split(',').each do |cn|
                  @cns << cn.downcase.split('dns:')[1] if cn.downcase =~ /^dns:/
              end
            end
          }
        end
      rescue Exception => e
        next
      end
     
      # Checks if is a wildcard certificate
      @cns.each do |cn|
        if cn =~ /^\*\./
          $LOG.warn "Detected a wildcard entry in X.509 certificate for: #{cn}"
          next
        else
          @hosts << { :hostname => cn } if !cn.nil?
        end
      end
    end

    return @hosts
  end

  def timeout
    return @hosts
  end
end
