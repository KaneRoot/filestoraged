require "uuid"
require "openssl"
require "json"
require "base64"

class FileStorage::Request
	IPC::JSON.message Login, 0 do
		property mid : String = ""

		property token : String

		def initialize(@token)
			@mid = UUID.random.to_s
		end

		def handle(filestoraged : FileStorage::Service, event : IPC::Event::Events)
			logged_users = filestoraged.logged_users

			user, _ = filestoraged.decode_token token

			# FIXME: Maybe this should be moved to FileStorage::Service
			fd = event.fd

			filestoraged.logged_users[fd]       = user

			user_data = filestoraged.get_user_data user.uid

			return Response::Login.new @mid
		rescue e
			return Errors::GenericError.new @mid, "unauthorized"
		end
	end
	FileStorage.requests << Login
end

class FileStorage::Response
	IPC::JSON.message Login, 5 do
		property mid : String
		def initialize(@mid)
		end
	end
end
