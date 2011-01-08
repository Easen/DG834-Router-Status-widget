#! /usr/bin/ruby

require 'pathname'
require 'net/http'
require 'uri'
require 'net/telnet'
# Ensure the script can be executed from anywhere
$: << File.dirname( __FILE__) 
require 'json'

# Exception
class DG384Exception < RuntimeError
end


class DG384
	attr_accessor :host, :adminUser, :adminPassword
	
	# Mapping of the 'adsl info' bash command
	@@mapping = Hash[
		"status" => "Current Training Status",
		"mode" => "Current trained adsl mode",
		"trainedPath" => "Current trained adsl path",
		"downstreamBitRate" => "Downstream Bit Rate",
		"downstreamNoiseMargin" => "Downstream Noise Margin",
		"downstreamAttenuation" => "Downstream Attenuation",
		"upstreamBitRate" => "Upstream Bit Rate",
		"upstreamNoiseMargin" => "Upstream Noise Margin",
		"upstreamAttenuation" => "Upstream Attenuation"
	]
	
	def initialize(host = "192.168.0.1", adminUser = "admin", adminPassword = "password")
		@host = host
		@adminUser = adminUser
		@adminPassword = adminPassword
 	end
 	
 	def enableDebugMode
 		url = URI.parse('http://' + @host + '/setup.cgi?todo=debug')

		req = Net::HTTP::Get.new(url.path)
		
		req.basic_auth @adminUser, @adminPassword
		res = Net::HTTP.new(url.host, url.port).start {|http| 
			http.read_timeout = 3 
			http.request(req) 
		}

		if res.header.code == '200'
			return true
		end
		
		return false
 	end
 	
 	def getADSLInfo
 		# Enabled Debug mode for telnet access
 		if false == self.enableDebugMode 
 			raise DG384Exception, "Could not enable DEBUG mode", caller
 		end
 		
 		# Connect to the router via telnet and run 'adsl info'
 		localhost = Net::Telnet::new(
 			"Host" => "192.168.0.1",
            "Timeout" => 10
        )
		localhost.waitfor("Prompt" => /[$%#>] \z/n)
		adslInfo = localhost.cmd("adsl info")
		localhost.close
		
		# Check the response
		if adslInfo == nil
			raise DG384Exception, "Could not get ADSL Info", caller
		end
		
		# Parse the response
		adslInfo = adslInfo.split(/\n/)[1, 8]
		lookup = @@mapping.invert

		values = Hash[(@@mapping.values)]

		adslInfo.each {|line| 
			value = line.split(/\s+:\s+/)
			# Match the mapping
			if @@mapping.has_value?(value[0]) && value[1] != nil
				values[lookup[value[0]]] = value[1]
			end
		}
		
		return values
 	end
end

# Check if any arguments have been passed in, if so use them
if ARGV.length == 3 then
	router = DG384.new(ARGV[0], ARGV[1], ARGV[2])
else
	router = DG384.new
end

# Output the adslInfo
begin
	output = router.getADSLInfo
rescue
	output = Hash["error" => "Could not get ADSL info"]
end

# Encode to JSON
puts JSON::dump(output)
