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


# keep track of connected users and their requests
# TODO: requests should be handled concurrently
class User
	property uid : Int32
	property token : Token
	property requests : Array(Request)

	def initialize(@token)
		@uid = token.uid
	end
end

# list of connected users
# fd => uid
connected_users = Hash(Int32, Int32).new
users_status = Hash(Int32, User).new
 
service = IPC::SwitchingService.new service_name

def receiving_files(user : User, event : IPC::Event::Message)
end

# Could be the reception of a file or a file request
def request_handling(user : User, event : IPC::Event::Message)
	puts "request handling"

	#
	# Here we get requests from the message received
	#

end

service.loop do |event|
	case event
	when IPC::Event::Timer
		puts "#{CORANGE}IPC::Event::Timer#{CRESET}"

	when IPC::Event::Connection
		puts "#{CBLUE}IPC::Event::Connection: #{event.connection.fd}#{CRESET}"

	when IPC::Event::Disconnection
		puts "#{CBLUE}IPC::Event::Disconnection: #{event.connection.fd}#{CRESET}"

		connected_users.select! do |fd, uid|
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
		if userid = connected_users[event.connection.fd]?
			puts "User is connected: #{user.token.login}"
			request_handling users_status[userid], event
		else
			puts "User is not currently connected"

			# The first message sent to the server has to be the AuthenticationMessage.
			# Users sent their token (JWT) to authenticate themselves.
			# The token contains the user id, its login and a few other parameters.
			# (see the authd documentation).
			authentication_message =
				AuthenticationMessage.from_json(
					String.new event.message.payload
				)

			# Is the user already recorded in users_status?
			if users_status[authentication_message.token.uid]?
				puts "We already knew the user #{authentication_message.token.uid}"
				pp! users_status[authentication_message.token.uid]
			else
				# AuthenticationMessage includes requests.
				new_user =
					User.new authentication_message.token,
						authentication_message.requests

				connected_users[event.connection.fd] = new_user.uid

				# record the new user in users_status
				users_status[new_user.uid] = new_user

				puts "New user is: #{new_user.token.login}"
			end

			# The user is now connected.
			user = users_status[authentication_message.token.uid]

			# We verify the user's rights to upload files.
			# TODO RIGHTS
			# if user wants to upload but not allowed to: Response
			# if user wants to get a file but not allowed to: Response

			# The user is authorized to upload files.

			# TODO: quotas
			# Quotas are not defined yet.

			# Sending a response.
			# The response is "Ok" when the message is well received and authorized.
			response = Response.new authentication_message.mid, "Ok"
			event.connection.send MessageType::Response.to_u8, response.to_json
		end
	else
		raise "Event type not supported."
	end
end
