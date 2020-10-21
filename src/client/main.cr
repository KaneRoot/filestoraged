require "option_parser"
require "authd"
require "ipc"
require "json"

require "base64"

require "./authd_api.cr"
require "./lib.cr"
require "../server/network.cr"
require "../server/storage.cr"
require "../server/storage/*"

# TODO
# For now, this example only upload files.
# In a near future, we should be able to download files, too.

service_name = "filestorage"

files_and_directories_to_transfer = Array(String).new

authd_login : String = "test"
authd_pass  : String = "test"

OptionParser.parse do |parser|
	parser.on "-s service-name",
		"--service-name service-name",
		"Service name." do |name|
		service_name = name
	end

	parser.on "-l login",
		"--login login-name",
		"Login name for authd." do |name|
		authd_login = name
	end

	parser.on "-p pass",
		"--pass pass",
		"Password for authd." do |pass|
		authd_pass = pass
	end

	parser.unknown_args do |arg|
		files_and_directories_to_transfer = arg
	end

	parser.on "-h", "--help", "Show this help" do
		puts parser
		puts "program [OPTIONS] <files-to-upload>"
		exit -1
	end
end


#
# Verify we can read files
#

files = [] of String

puts "files and directories to transfer"
files_and_directories_to_transfer.each do |f|
	if File.directory? f
		# TODO
		puts "Directories not supported, for now"
	elsif File.file?(f) && File.readable? f
		files << f
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

#
# Connection to the service
#

# Authentication.
pp! authd_login
pp! authd_pass
token = authd_get_token login: authd_login, pass: authd_pass

# Connection and authentication to filestoraged.
client = FileStorage::Client.new token, service_name
client.login

files.each do |file|
	puts "upload: #{file}"
	pp! client.upload file
	puts "transfer"
	client.transfer file
end

client.close
