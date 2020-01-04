
require "dodb"
require "base64"

# reception of a file chunk
def hdl_transfer(message : FileStorage::Transfer,
	user : User,
	event : IPC::Event::Message) : FileStorage::Response
	puts "receiving a file"

	mid = message.mid
	mid ||= "no message id"

	# pp! transfer_message

	file_info = user.uploads.select do |v|
		v.file.digest == message.filedigest
	end.first.file

	pp! file_info

	# TODO: verify the digest
	# TODO: store the file
	# TODO: register the file, with its tags

	# puts "chunk: #{transfer_message.chunk}"
	# puts "data: #{Base64.decode transfer_message.data}"

	FileStorage::Response.new mid, "Ok"

rescue e
	puts "Error handling transfer: #{e.message}"
	FileStorage::Response.new mid.not_nil!, "Not Ok", "Unexpected error: #{e.message}"
end

# TODO
# the client sent an upload request
def hdl_upload(request : FileStorage::UploadRequest,
	user : User,
	event : IPC::Event::Message) : FileStorage::Response

	puts "hdl upload: mid=#{request.mid}"
	pp! request

	FileStorage::Response.new request.mid, "Upload OK"
end

# TODO
# the client sent a download request
def hdl_download(request : FileStorage::DownloadRequest,
	user : User,
	event : IPC::Event::Message) : FileStorage::Response

	puts "hdl download: mid=#{request.mid}"
	pp! request

	FileStorage::Response.new request.mid, "Download OK"
end


# Entry point for request management
# Each request should have a response.
# Then, responses are sent in a single message.
def hdl_requests(requests : Array(FileStorage::Request),
	user : User,
	event : IPC::Event::Message) : Array(FileStorage::Response)

	puts "hdl request"
	responses = Array(FileStorage::Response).new

	requests.each do |request|
		case request
		when FileStorage::DownloadRequest
			responses << hdl_download request, user, event
		when FileStorage::UploadRequest
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
		FileStorage::Authentication.from_json(
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
				authentication_message.uploads,
				authentication_message.downloads

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
	response = FileStorage::Responses.new authentication_message.mid, "Ok", responses
	event.connection.send FileStorage::MessageType::Responses.to_u8, response.to_json
	pp! FileStorage::MessageType::Responses.to_u8
	pp! response
end
