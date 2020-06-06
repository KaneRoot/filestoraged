require "option_parser"
require "ipc"
require "json"
require "authd"

require "colorize"

require "weird-crystal-base"

require "../common/colors"
# require "../common/filestorage.cr"

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
require "json"

class FileStorage::Service < IPC::Service
	# List of connected users (fd => uid).
	property connected_users = Hash(Int32, Int32).new

	# users_status: keep track of the users' status even if they are disconnected,
	#               allowing the application to handle connection problems.
	property users_status : Hash(Int32, UserData) = Hash(Int32, UserData).new

	# Actual storage.
	getter storage             : FileStorage::Storage

	getter logged_users        : Hash(Int32, AuthD::User::Public)
	getter logged_connections  : Hash(Int32, IPC::Connection)
	getter all_connections     : Array(Int32)

	@auth : AuthD::Client
	@auth_key : String

	def initialize(storage_directory, @auth_key)
		# Data and metadata storage directory.
		@storage = FileStorage::Storage.new storage_directory

		@logged_users       = Hash(Int32, AuthD::User::Public).new
		@logged_connections = Hash(Int32, IPC::Connection).new
		@all_connections    = Array(Int32).new

		@auth = AuthD::Client.new
		@auth.key = @auth_key

		super "filestorage"
	end

	def get_logged_user(event : IPC::Event::Events)
		fd = event.connection.fd

		@logged_users[fd]?
	end

	def info(message)
		STDOUT << ":: ".colorize(:green) << message.colorize(:white) << "\n"
	end
	def warning(message)
		STDERR << "?? ".colorize(:yellow) << message.colorize(:yellow) << "\n"
	end
	def error(message)
		STDERR << "!! ".colorize(:red) << message.colorize(:red) << "\n"
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

	# TODO: could be useful to send notifications.
	#def send_notifications(fd : Int32, value : Int32)
		# @all_connections.select(&.!=(fd)).each do |fd| ... end
		# IPC::Connection.new(fd).send Response::Something.new ...
	#end

	def run
		info "Starting filestoraged"

		self.loop do |event|
			begin

				case event
				when IPC::Event::Timer
					puts "#{CORANGE}IPC::Event::Timer#{CRESET}"

				when IPC::Event::Connection
					puts "#{CBLUE}IPC::Event::Connection: #{event.connection.fd}#{CRESET}"
					@all_connections << event.connection.fd

				when IPC::Event::Disconnection
					puts "#{CBLUE}IPC::Event::Disconnection: #{event.connection.fd}#{CRESET}"
					fd = event.connection.fd

					@logged_connections.delete fd
					@logged_users.delete fd
					@all_connections.select! &.!=(fd)

					@connected_users.select! do |fd, uid|
						fd != event.connection.fd
					end

				when IPC::Event::ExtraSocket
					puts "#{CRED}IPC::Event::ExtraSocket: should not happen in this service#{CRESET}"

				when IPC::Event::Switch
					puts "#{CRED}IPC::Event::Switch: should not happen in this service#{CRESET}"

				# IPC::Event::Message has to be the last entry
				# because ExtraSocket and Switch inherit from Message class
				when IPC::Event::Message
					puts "#{CBLUE}IPC::Event::Message#{CRESET}: #{event.connection.fd}"

					request_start = Time.utc

					request = parse_message FileStorage.requests, event.message

					if request.nil?
						raise "unknown request type"
					end

					info "<< #{request.class.name.sub /^FileStorage::Request::/, ""}"

					response = request.handle self, event
					response_type = response.class.name

					if response.responds_to?(:reason)
						warning ">> #{response_type.sub /^FileStorage::Errors::/, ""} (#{response.reason})"
					else
						info ">> #{response.class.name.sub /^FileStorage::Response::/, ""}"
					end

					#################################################################
					# THERE START
					#################################################################

#					# The first message sent to the server has to be the AuthenticationMessage.
#					# Users sent their token (JWT) to authenticate themselves.
#					# The token contains the user id, its login and a few other parameters.
#					# (see the authd documentation).
#					# TODO: for now, the token is replaced by a hardcoded one, for debugging
#
#					mtype = FileStorage::MessageType.new event.message.utype.to_i32
#
#					# First, the user has to be authenticated unless we are receiving its first message.
#					userid = Context.connected_users[event.connection.fd]?
#
#					# If the user is not yet connected but does not try to perform authentication.
#					if ! userid && mtype != FileStorage::MessageType::Authentication
#						# TODO: replace this with an Error message.
#						mid = "no message id"
#						response = FileStorage::Response.new mid, "Not OK", "Action on non connected user"
#						do_response event, response
#					end
#
#					case mtype
#					when .authentication?
#						puts "Receiving an authentication message"
#						# Test if the client is already authenticated.
#						if userid
#							user = Context.users_status[userid]
#							raise "Authentication message while the user was already connected: this should not happen"
#						else
#							puts "User is not currently connected"
#							hdl_authentication event
#						end
#
#					when .upload_request?
#						puts "Upload request"
#						request = FileStorage::UploadRequest.from_json(
#							String.new event.message.payload
#						)
#						response = hdl_upload request, Context.users_status[userid]
#						do_response event, response
#
#					when .download_request?
#						puts "Download request"
#						request = FileStorage::DownloadRequest.from_json(
#							String.new event.message.payload
#						)
#						response = hdl_download request, Context.users_status[userid]
#						do_response event, response
#
#					when .transfer?
#						# throw an error if the user isn't recorded
#						unless user = Context.users_status[userid]?
#							raise "The user isn't recorded in the users_status structure"
#						end
#
#						transfer = FileStorage::PutChunk.from_json(
#							String.new event.message.payload
#						)
#						response = hdl_transfer transfer, Context.users_status[userid]
#
#						do_response event, response
#					end

					#################################################################
					# FINISH
					#################################################################


					# If clients sent requests with an “id” field, it is copied
					# in the responses. Allows identifying responses easily.
					response.id = request.id

					event.connection.send response

					duration = Time.utc - request_start
					puts "request took: #{duration}"
				else
					warning "unhandled IPC event: #{event.class}"
				end

			rescue exception
				error "exception: #{typeof(exception)} - #{exception.message}"
			end
		end
	end

	def self.from_cli
		storage_directory = "files/"
		key = "nico-nico-nii" # Default authd key, as per the specs. :eyes:

		OptionParser.parse do |parser|
			parser.banner = "usage: filestoraged [options]"

			parser.on "-r root-directory",
				"--root-directory dir",
				"The root directory for FileStoraged." do |opt|
				storage_directory = opt
			end

			parser.on "-h",
				"--help",
				"Displays this help and exits." do
				puts parser
				exit 0
			end

			# FIXME: Either make this mandatory or print a warning if missing.
			parser.on "-k file",
				"--key file",
				"Reads the authentication key from the provided file." do |file|
				key = File.read(file).chomp
			end
		end

		::FileStorage::Service.new storage_directory, key
	end
end

FileStorage::Service.from_cli.run
