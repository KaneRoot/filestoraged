require "option_parser"
require "ipc/json"
require "authd"

require "colorize"

require "baguette-crystal-base"

require "../colors"
# require "../filestorage.cr"

# TODO: if the user is disconnected, we should ask him if it still want to process
#       for old requests.
#
# Example: the user is on a web page, the connection is broken for some reason.
#          The user can still browse the website, change page and discard what
#          he was doing. Regardless of the result. With or without finishing to
#          upload or download its files.

# TODO:
# * Elegantly handling errors.
# * Store the file, @root/files/UID for example: ./files/UID.
# * Knowing which parts of the files are still to be sent.
# * Rights.
# * Quotas.

require "./storage.cr"
require "./network.cr"

require "dodb"

class IPC::JSON
	def handle(filestoraged : FileStorage::Service, event : IPC::Event::Events)
		raise "unknown request"
	end
end

module FileStorage
	class Exception < ::Exception
	end
	class AuthorizationException < ::Exception
	end
	class NotLoggedException < ::Exception
	end
	class AdminAuthorizationException < ::Exception
	end
	class FileTooBig < ::Exception
	end
end

class Baguette::Configuration
	class FileStorage < Base
		property max_file_size   : UInt64 = 10_000_000 # default, 10 MB
		property storage         : String = "files/"
		property db_reindex      : Bool   = false

		property faulty          : Bool   = false      # To test clients on transfer errors.

		property verbosity       : Int32  = 3
		property ipc_timer       : Int32  = 30_000     # Default timer: 30 seconds.
		property print_ipc_timer : Bool   = false

		def initialize
		end
	end
end



class FileStorage::Service < IPC::Server
	# List of connected users (fd => uid).
	property connected_users = Hash(Int32, Int32).new

	# users_status: keep track of the users' status even if they are disconnected,
	#               allowing the application to handle connection problems.
	property users_status : Hash(Int32, UserData) = Hash(Int32, UserData).new

	# Actual storage.
	getter storage             : FileStorage::Storage

	getter logged_users        : Hash(Int32, AuthD::User::Public)
	getter all_connections     : Array(Int32)

	property max_file_size     : UInt64 = 10_000_000 # Bytes

	property print_timer       : Bool = false

	property faulty            : Bool = false
	property faulty_nb         : Int32 = 0

	@auth : AuthD::Client
	@auth_key : String

	def initialize(storage_directory, @auth_key, reindex : Bool)
		# Data and metadata storage directory.
		@storage = FileStorage::Storage.new storage_directory, reindex

		@logged_users       = Hash(Int32, AuthD::User::Public).new
		@all_connections    = Array(Int32).new

		@auth = AuthD::Client.new
		@auth.key = @auth_key

		super "filestorage"
	end

	def get_logged_user(event : IPC::Event::Events)
		fd = event.fd

		@logged_users[fd]?
	end

	def decode_token(token : String)
		@auth.decode_token token
	end

	def get_user_data(uid : Int32)
		@storage.user_data_per_user.get uid.to_s
	rescue e : DODB::MissingEntry
		entry = UserData.new uid
		entry
	end

	def get_user_data(user : ::AuthD::User::Public)
		get_user_data user.uid
	end

	def update_user_data(user_data : UserData)
		@storage.user_data_per_user.update_or_create user_data.uid.to_s, user_data
	end

	def handle_request(event : IPC::Event::MessageReceived)

		request = FileStorage.requests.parse_ipc_json event.message
		if request.nil?
			raise "unknown request type"
		end

		request_name = request.class.name.sub /^FileStorage::Request::/, ""
		Baguette::Log.info "<< #{request_name}"

		response = FileStorage::Errors::GenericError.new "#{request.id}", "generic error"

		request_id = "#{request.id}"

		response = begin
			request.handle self, event
		rescue e : AuthorizationException
			Baguette::Log.warning "#{request_name} authorization error"
			Errors::Authorization.new request_id
		rescue e : AdminAuthorizationException
			Baguette::Log.warning "#{request_name} no admin authorization"
			Errors::Authorization.new request_id
		rescue e : NotLoggedException
			Baguette::Log.warning "#{request_name} user not logged"
			Errors::GenericError.new request_id, "user not logged"
		rescue e : FileTooBig
			Baguette::Log.warning "#{request_name} file too big: #{e.message}"
			Errors::FileTooBig.new request_id, @max_file_size
		rescue e
			Baguette::Log.error "#{request_name} generic error #{e}"
			Errors::GenericError.new request_id, "unexpected error"
		end

		# If clients sent requests with an “id” field, it is copied
		# in the responses. Allows identifying responses easily.
		response.id = request.id

		send event.fd, response

		response_name = response.class.name.sub /^FileStorage::(Response|Errors)::/, ""
		if response.responds_to?(:reason)
			Baguette::Log.warning ">> #{response_name} (#{response.reason})"
		else
			Baguette::Log.info ">> #{response_name}"
		end
	end

	def run
		Baguette::Log.title "Starting filestoraged"

		self.loop do |event|
			begin

				case event
				when IPC::Event::Timer
					Baguette::Log.debug "IPC::Event::Timer" if @print_timer

				when IPC::Event::Connection
					Baguette::Log.debug "IPC::Event::Connection: #{event.fd}"
					@all_connections << event.fd

				when IPC::Event::Disconnection
					Baguette::Log.debug "IPC::Event::Disconnection: #{event.fd}"
					fd = event.fd

					@logged_users.delete fd
					@all_connections.select! &.!=(fd)

					@connected_users.select! do |fd, uid|
						fd != event.fd
					end

				when IPC::Event::ExtraSocket
					Baguette::Log.warning "IPC::Event::ExtraSocket: should not happen in this service"

				when IPC::Event::Switch
					Baguette::Log.warning "IPC::Event::Switch: should not happen in this service"

				# IPC::Event::Message has to be the last entry
				# because ExtraSocket and Switch inherit from Message class
				when IPC::Event::MessageReceived
					Baguette::Log.debug "IPC::Event::Message: #{event.fd}"

					request_start = Time.utc
					handle_request event
					duration = Time.utc - request_start
					Baguette::Log.debug "request took: #{duration}"

				when IPC::Event::MessageSent
					Baguette::Log.debug "IPC::Event::MessageSent: #{event.fd}"
				else
					Baguette::Log.warning "unhandled IPC event: #{event.class}"
				end

			rescue exception
				Baguette::Log.error "exception: #{typeof(exception)} - #{exception.message}"
			end
		end
	end

	def self.from_cli

		simulation, no_configuration, configuration_file = Baguette::Configuration.option_parser

		# Authd configuration.
		authd_configuration = if no_configuration
			Baguette::Log.info "do not load a configuration file."
			Baguette::Configuration::Auth.new
		else
			# Configuration file is for altideald.
			Baguette::Configuration::Auth.get || Baguette::Configuration::Auth.new
		end
		if key_file = authd_configuration.shared_key_file
			authd_configuration.shared_key = File.read(key_file).chomp
		end

		# FileStoraged configuration.
		configuration = if no_configuration
			Baguette::Log.info "do not load a configuration file."
			Baguette::Configuration::FileStorage.new
		else
			Baguette::Configuration::FileStorage.get || Baguette::Configuration::FileStorage.new
		end

		Baguette::Context.verbosity = configuration.verbosity

		OptionParser.parse do |parser|
			parser.banner = "usage: filestoraged [options]"

			parser.on "-r root-directory",
				"--root-directory dir",
				"The root directory for FileStoraged." do |opt|
				configuration.storage = opt
				Baguette::Log.info "Storage directory: #{configuration.storage}"
			end

			parser.on "-t timer",
				"--timer timer",
				"Timer. Default: 30 000 (30 seconds)." do |t|
				configuration.ipc_timer = t.to_i
				Baguette::Log.info "Timer: #{configuration.ipc_timer}"
			end

			parser.on "-I",
				"--re-index",
				"Reindex the database." do
				Baguette::Log.info "Re-index everything!"
				configuration.db_reindex = true
			end

			parser.on "-m size",
				"--max-size size",
				"Maximum file size (KB). Default: 10 MB." do |s|
				Baguette::Log.info "Maximum file size: #{s}"
				configuration.max_file_size = s.to_u64 * 1000
			end

			parser.on "-f",
				"--faulty",
				"Messages will be dropped, rate: 1/5." do
				Baguette::Log.info "Faulty: messages will be dropped."
				configuration.faulty = true
			end

			parser.on "-k file",
				"--key file",
				"Reads the authentication key from the provided file." do |file|
				authd_configuration.shared_key = File.read(file).chomp
			end

			parser.on "-h", "--help", "Displays this help and exits." do
				puts parser
				exit 0
			end
		end

		if simulation
			pp! authd_configuration
			pp! configuration
			exit 0
		end

		::FileStorage::Service.new(configuration.storage,
			authd_configuration.shared_key,
			configuration.db_reindex).tap do |service|

			service.base_timer    = configuration.ipc_timer
			service.timer         = configuration.ipc_timer
			service.max_file_size = configuration.max_file_size
			service.print_timer   = configuration.print_ipc_timer
			service.faulty        = configuration.faulty
		end
	end
end

FileStorage::Service.from_cli.run
