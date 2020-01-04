
require "dodb"
require "base64"

# reception of a file chunk
def hdl_transfer(message : FileStorage::Message::Transfer,
	user : User,
	event : IPC::Event::Message) : FileStorage::Message::Response
	puts "receiving a file"

	transfer_message = FileStorage::Message::Transfer.from_json(
		String.new event.message.payload
	)

	pp! transfer_message

	# puts "chunk: #{transfer_message.chunk}"
	# puts "data: #{Base64.decode transfer_message.data}"

	FileStorage::Message::Response.new message.mid, "Ok"
end

# TODO
# the client sent an upload request
def hdl_upload(request : FileStorage::Message::UploadRequest,
	user : User,
	event : IPC::Event::Message) : FileStorage::Message::Response

	puts "hdl upload: mid=#{request.mid}"
	pp! request

	FileStorage::Message::Response.new request.mid, "Upload OK"
end

# TODO
# the client sent a download request
def hdl_download(request : FileStorage::Message::DownloadRequest,
	user : User,
	event : IPC::Event::Message) : FileStorage::Message::Response

	puts "hdl download: mid=#{request.mid}"
	pp! request

	FileStorage::Message::Response.new request.mid, "Download OK"
end


# Entry point for request management
# Each request should have a response.
# Then, responses are sent in a single message.
def hdl_requests(requests : Array(FileStorage::Message::Request),
	user : User,
	event : IPC::Event::Message) : Array(FileStorage::Message::Response)

	puts "hdl request"
	responses = Array(FileStorage::Message::Response).new

	requests.each do |request|
		case request
		when FileStorage::Message::DownloadRequest
			responses << hdl_download request, user, event
		when FileStorage::Message::UploadRequest
			responses << hdl_upload request, user, event
		else
			raise "request not understood"
		end

		puts
	end

	responses
end

# store the client in connected_users and users_status
# if already in users_status: 
#   check if the requests are the same
#     if not: add them to the user structure in users_status
def hdl_authentication(event : IPC::Event::Message)

	authentication_message =
		FileStorage::Message::Authentication.from_json(
			String.new event.message.payload
		)

	userid = authentication_message.token.uid

	puts "user authentication: #{userid}"

	# Is the user already recorded in users_status?
	if Context.users_status[userid]?
		puts "We already knew this user"

		Context.connected_users[event.connection.fd] = userid
		# TODO
		pp! Context.connected_users
		pp! Context.users_status[userid]
	else
		# AuthenticationMessage includes requests.
		new_user =
			User.new authentication_message.token,
				[ authentication_message.uploads, authentication_message.downloads ].flatten

		Context.connected_users[event.connection.fd] = userid

		# record the new user in users_status
		Context.users_status[userid] = new_user

		puts "New user is: #{new_user.token.login}"
	end

	# The user is now connected.
	user = Context.users_status[userid]

	# We verify the user's rights to upload files.
	# TODO RIGHTS
	# if user wants to upload but not allowed to: Response
	# if user wants to get a file but not allowed to: Response

	# The user is authorized to upload files.

	# TODO: quotas
	# Quotas are not defined yet.

	responses = hdl_requests [ authentication_message.uploads, authentication_message.downloads ].flatten,
		Context.users_status[userid],
		event

	# Sending a response, containing a response for each request.
	# The response is "Ok" when the message is well received and authorized.
	response = FileStorage::Message::Responses.new authentication_message.mid, "Ok", responses
	event.connection.send FileStorage::MessageType::Responses.to_u8, response.to_json
	pp! FileStorage::MessageType::Responses.to_u8
	pp! response
end
