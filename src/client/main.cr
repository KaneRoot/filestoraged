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

	class_property path        : String = "."

	class_property args = Array(String).new

	class_property service_name = "filestorage"
	class_property command = "unknown"
end

opt_unknown_args = ->(parser : OptionParser) {
	parser.unknown_args do |arg|
		Context.args = arg
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

	parser.on "-d directory",
		"--directory path",
		"Path where to put downloaded files." do |path|
		Context.path = path
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

	Context.args.each do |f|
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
		file_info = File.open(file) do |f|
			FileStorage::FileInfo.new f
		end
		response = client.upload file
		case response
		when FileStorage::Errors::FileFullyUploaded
			Baguette::Log.warning "file #{file} already uploaded, digest: #{file_info.digest}"
			next
		when FileStorage::Errors::FileTooBig
			Baguette::Log.warning "file #{file} too big, accepting up to #{response.limit} bytes"
			next
		end
		Baguette::Log.info "transfering: #{file}"
		client.transfer file
	end
end

def get(client : FileStorage::Client)
	files = Context.args
	files.each do |filedigest|
		response = client.download filedigest
		case response
		when FileStorage::Response::Download
			Baguette::Log.info "downloading file #{filedigest} with #{response.file_info.nb_chunks} chunks"
			client.get_chunks response, Context.path
		else
			Baguette::Log.error "#{response.class.name}"
			next
		end
	end
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
