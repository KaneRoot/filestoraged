require "option_parser"
require "ipc"
require "json"

require "base64"

require "../common/filestorage.cr"

# TODO
# For now, this example only upload files.
# In a near future, we should be able to download files, too.

service_name = "filestorage"

files_and_directories_to_transfer = Array(String).new

# This is the requests we will send to the server
upload_requests = Array(FileStorage::UploadRequest).new


OptionParser.parse do |parser|
	parser.on "-s service-name",
		"--service-name service-name",
		"Service name." do |name|
		service_name = name
	end

	parser.unknown_args do |arg|
		files_and_directories_to_transfer = arg
	end

	parser.on "-h", "--help", "Show this help" do
		puts parser
		puts "program [OPTIONS] <files-to-upload>"
		exit 0
	end
end


#
# Get informations about files to transfer
# For now, we only want to upload files, so we create an UploadRequest
#

files_info = Hash(String, FileStorage::FileInfo).new


puts "files and directories to transfer"
files_and_directories_to_transfer.each do |f|
	if File.directory? f
		# TODO
		puts "Directories not supported, for now"
	elsif File.file?(f) && File.readable? f
		File.open(f) do |file|
			files_info[file.path] = FileStorage::FileInfo.new file
		end
	else
		if ! File.exists? f
			puts "#{f} does not exist"
		elsif ! File.file? f
			puts "#{f} is neither a directory or a file"
		elsif ! File.readable? f
			puts "#{f} is not readable"
		end
	end
end

files_info.values.each do |file_info|
	upload_requests << FileStorage::UploadRequest.new file_info
end

# pp! upload_requests

#
# Connection to the service
#

client = IPC::Client.new service_name

#
# Sending the authentication message, including files info
#

token = FileStorage::Token.new 1002, "karchnu"
authentication_message = FileStorage::Authentication.new token, upload_requests
pp! authentication_message
client.send FileStorage::MessageType::Authentication.to_u8, authentication_message.to_json

#
# Receiving a response
#

m = client.read
# puts "message received: #{m.to_s}"
# puts "message received payload: #{String.new m.payload}"

response = FileStorage::Response.from_json(String.new m.payload)

if response.mid == authentication_message.mid
	puts "This is a response for the authentication message"
	pp! response
else
	raise "Message IDs from authentication message and its response differ"
end

#
# file transfer
#

def file_transfer(client : IPC::Client, file : File, file_info : FileStorage::FileInfo)
	buffer_size = 1_000

	buffer = Bytes.new buffer_size
	counter = 1
	size = 0

	while (size = file.read(buffer)) > 0
		# transfer message = file_info, chunk count, data (will be base64'd)
		transfer_message = FileStorage::Transfer.new file_info, counter, buffer[0 ... size]

		client.send FileStorage::MessageType::Transfer.to_u8, transfer_message.to_json
		counter += 1

		buffer = Bytes.new buffer_size


		# Check for the response
		m = client.read
		mtype = FileStorage::MessageType.new m.type.to_i32
		if mtype != FileStorage::MessageType::Response
			pp! m
			raise "Message received was not expected: #{mtype}"
		end

		response = FileStorage::Response.from_json(String.new m.payload)

		if response.mid != transfer_message.mid
			raise "Message received has a wrong mid: #{response.mid} != #{transfer_message.mid}"
		else
			pp! response
		end
	end
end

puts "transfer"

files_info.keys.each do |file_path|
	puts "- #{file_path}"

	File.open(file_path) do |file|
		file_transfer client, file, files_info[file_path]
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
