require "uuid"
require "openssl"
require "json"
require "base64"

class FileStorage::Request
	JSONIPC.request Login, 0 do
		property mid : String = ""

		property token : String

		def initialize(@token)
			@mid = UUID.random.to_s
		end

		def handle(filestoraged : FileStorage::Service, event : IPC::Event::Events)
			logged_users = filestoraged.logged_users

			user, _ = filestoraged.decode_token token

			# FIXME: Maybe this should be moved to FileStorage::Service
			fd = event.connection.fd

			filestoraged.logged_users[fd]       = user
			filestoraged.logged_connections[fd] = event.connection

			user_data = filestoraged.get_user_data user.uid

			return Response::Login.new @mid
		rescue e
			return Response::Error.new @mid, "unauthorized"
		end
	end
	FileStorage.requests << Login
end

class FileStorage::Client
	def login(token : String)
		request = FileStorage::Request::Login.new token
		send request

		response = parse_message [ FileStorage::Response::Login, FileStorage::Response::Error ], read

		case response
		when FileStorage::Response::Login
			# Received favorites, likes, etc.
		when FileStorage::Response::Error
			raise "user was not logged in: #{response.reason}"
		end

		response
	end
end

class FileStorage::Response
	JSONIPC.request Login, 5 do
		property mid : String
		def initialize(@mid)
		end
	end
end