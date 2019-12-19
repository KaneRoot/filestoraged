require "option_parser"
require "ipc"
require "json"

require "./colors"

# require "dodb"

require "./common.cr"

storage_directory = "./storage"
service_name = "filestorage"


OptionParser.parse do |parser|
	parser.on "-d storage-directory",
		"--storage-directory storage-directory",
		"The directory where to put uploaded files." do |opt|
		storage_directory = opt
	end

	parser.on "-s service-name", "--service-name service-name", "Service name." do |name|
		service_name = name
	end

	parser.on "-h", "--help", "Show this help" do
		puts parser
		exit 0
	end
end


# keep track of connected users
class User
	property token : Token
	def initialize(@token)
	end
end

# list of connected users
# fd => User
connected_users = Hash(Int32, User).new

service = IPC::SwitchingService.new service_name

service.loop do |event|
	case event
	when IPC::Event::Timer
		puts "#{CORANGE}IPC::Event::Timer#{CRESET}"

		# puts "Disconnected client is: #{client_name}"

	when IPC::Event::Connection
		puts "#{CBLUE}IPC::Event::Connection: #{event.connection.fd}#{CRESET}"

	when IPC::Event::Disconnection
		puts "#{CBLUE}IPC::Event::Disconnection: #{event.connection.fd}#{CRESET}"

		connected_users.select! do |fd, user|
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

		# 1. test if the client is already authenticated
		if user = connected_users[event.connection.fd]?
			puts "User is connected: #{user.token.login}"
		else
			puts "User is not currently connected"

			authentication_message = AuthenticationMessage.from_json(String.new event.message.payload)

			authentication_message.files.each do |file|
				puts "uploading #{file.name} - #{file.size} bytes"
			end

			new_user = User.new authentication_message.token
			connected_users[event.connection.fd] = new_user
			puts "New user is: #{new_user.token.login}"

			response = Response.new authentication_message.mid, "Ok"
			event.connection.send 2.to_u8, response.to_json
		end
		

		# puts "New connected client is: #{client_name}"

		# The first message is the connection.
		# Users sent their token (JWT) to authenticate.
		# From the token, we get the user id, its login and a few other parameters (see the authd documentation).
	else
		raise "Event type not supported."
	end
end
