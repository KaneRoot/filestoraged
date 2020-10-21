require "option_parser"
require "authd"
require "ipc"
require "json"

require "base64"

require "baguette-crystal-base"

require "./authd_api.cr"
require "./lib.cr"
require "../server/network.cr"
require "../server/storage.cr"
require "../server/storage/*"

# TODO
# For now, this example only upload files.
# In a near future, we should be able to download files, too.

class Context
	class_property authd_login : String = "test"
	class_property authd_pass  : String = "test"

	class_property to_transfer = Array(String).new

	class_property service_name = "filestorage"
	class_property command = "unknown"
end

opt_unknown_args = ->(parser : OptionParser) {
	parser.unknown_args do |arg|
		Context.to_transfer = arg
	end
}

OptionParser.parse do |parser|
	parser.banner = "#{PROGRAM_NAME} [OPTIONS] <files-to-upload>"
	parser.on "-s service-name",
		"--service-name service-name",
		"Service name." do |name|
		Context.service_name = name
	end

	parser.on "get", "Get files from IDs (file digests)." do
		parser.banner = "#{PROGRAM_NAME} get digest [digest…] [OPTIONS]"
		Context.command = "get"
		opt_unknown_args.call parser
	end
	parser.on "put", "Send files." do
		parser.banner = "#{PROGRAM_NAME} put path [path…] [OPTIONS]"
		Context.command = "put"
		opt_unknown_args.call parser
	end

	parser.on "-l login",
		"--login login-name",
		"Login name for authd." do |name|
		Context.authd_login = name
	end

	parser.on "-p pass",
		"--pass pass",
		"Password for authd." do |pass|
		Context.authd_pass = pass
	end

	parser.on "-v verbosity",
		"--verbosity level",
		"Verbosity. From 0 to 4." do |v|
		Baguette::Context.verbosity = v.to_i
	end

	parser.on "-h", "--help", "Show this help" do
		puts parser
		exit -1
	end
end


def put(client : FileStorage::Client)
	Baguette::Log.info "Putting files on the server"
	#
	# Verify we can read files
	#

	files = [] of String

	Baguette::Log.debug "files and directories to transfer"
	Context.to_transfer.each do |f|
		if File.directory? f
			# TODO
			Baguette::Log.warning "Directories not supported, for now"
		elsif File.file?(f) && File.readable? f
			files << f
		else
			if ! File.exists? f
				Baguette::Log.error "#{f} does not exist"
			elsif ! File.file? f
				Baguette::Log.error "#{f} is neither a directory or a file"
			elsif ! File.readable? f
				Baguette::Log.error "#{f} is not readable"
			end
		end
	end

	files.each do |file|
		Baguette::Log.info "upload: #{file}"
		pp! client.upload file
		Baguette::Log.debug "transfer"
		client.transfer file
	end
end

def get(client : FileStorage::Client)
	Baguette::Log.error "get command not available, yet"
end



def main
	#
	# Connection to the service
	#

	token = authd_get_token login: Context.authd_login, pass: Context.authd_pass

	# Connection and authentication to filestoraged.
	client = FileStorage::Client.new token, Context.service_name
	client.login

	case Context.command
	when /put/
		put client
	when /get/
		get client
	else
		Baguette::Log.error "unkown command"
	end

	client.close
end

main
