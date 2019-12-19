require "option_parser"
require "ipc"
require "json"

require "./common.cr"

service_name = "filestorage"

files_and_directories_to_transfer = Array(String).new


OptionParser.parse do |parser|
	parser.on "-s service-name", "--service-name service-name", "Service name." do |name|
		service_name = name
	end

	parser.unknown_args do |arg|
		files_and_directories_to_transfer = arg
	end

	parser.on "-h", "--help", "Show this help" do
		puts parser
		exit 0
	end
end

client = IPC::Client.new service_name


#
# Get informations about files to transfer
#

files_info = Array(FileInfo).new

puts "files and directories to transfer"
files_and_directories_to_transfer.each do |f|
	puts "- #{f}"

	if File.directory? f
		# TODO
		puts "Directories not supported, for now"
	elsif File.file?(f) && File.readable? f
		File.open(f) do |file|
			files_info << FileInfo.new file
		end
	else
		if File.exists? f
			puts "#{f} does not exist"
		elsif File.file? f
			puts "#{f} is neither a directory or a file"
		elsif File.readable? f
			puts "#{f} is not readable"
		end
	end
end

pp! files_info

exit 0

#
# Create the authentication message, including files info
#

token = Token.new 1002, "karchnu"
authentication_message = AuthenticationMessage.new token, files_info


client.send(1.to_u8, authentication_message.to_json)

m = client.read
# puts "message received: #{m.to_s}"
# puts "message received payload: #{String.new m.payload}"

response = Response.from_json(String.new m.payload)

if response.mid == authentication_message.mid
	puts "This is a response for the authentication message"
else
	puts "Message IDs from authentication message and its response differ"
end

#
# file transfer
#

puts "transfer"
files_and_directories_to_transfer.each do |f|
	puts "- #{f}"

	if File.directory? f
		# TODO
	elsif File.file?(f) && File.readable? f
		File.open(f) do |file|
			# TODO
			# file
		end
	end
end

client.close

#client.loop do |event|
#	case event
#	when IPC::Event::Message
#		puts "\033[32mthere is a message\033[00m"
#		puts event.message.to_s
#		client.close
#		exit
#	end
#end
