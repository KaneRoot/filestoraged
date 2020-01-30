
require "dodb"
require "base64"

require "../common/utils"

# XXX TODO FIXME: architectural questions
#   wonder why I should keep the user upload and download requests
#   the server can be just for uploads, delegating downloads to HTTP


# reception of a file chunk
def hdl_transfer(message : FileStorage::Transfer, user : User) : FileStorage::Response

	# We received a message containing a chunk of file.

	mid = message.mid
	mid ||= "no message id"

	# Get the transfer info from the db
	transfer_info = Context.db_by_filedigest.get message.filedigest

	if transfer_info.nil?
		# The user has to send an upload request before sending anything
		# If not the case, it should be discarded
		raise "file not recorded"
	end

	chunk_number = message.chunk.n

	data = Base64.decode message.data

	# TODO: verify that the chunk sent was really missing
	if transfer_info.chunks.select(chunk_number).size > 0
		write_a_chunk user.uid.to_s, transfer_info.file_info, chunk_number, data
	else
		raise "non existent chunk or already uploaded"
	end

	remove_chunk_from_db transfer_info, chunk_number

	# TODO: verify the digest, if no more chunks

	FileStorage::Response.new mid, "Ok"

rescue e
	puts "Error handling transfer: #{e.message}"
	FileStorage::Response.new mid.not_nil!, "Not Ok", "Unexpected error: #{e.message}"
end

# the client sent an upload request
def hdl_upload(request : FileStorage::UploadRequest, user : User) : FileStorage::Response

	mid = request.mid
	mid ||= "no message id"

	puts "hdl upload: mid=#{request.mid}"
	pp! request

	# TODO: verify the rights and quotas of the user
	# file_info attributes: name, size, nb_chunks, digest, tags

	# First: check if the file already exists
	transfer_info = Context.db_by_filedigest.get? request.file.digest
	if transfer_info.nil?
		# In case file informations aren't already registered
		# which is normal at this point
		transfer_info = TransferInfo.new user.uid, request.file
		Context.db << transfer_info
	else
		# File information already exists, request may be duplicated
		# In this case: ignore the upload request
	end

	FileStorage::Response.new request.mid, "Upload OK"
rescue e
	puts "Error handling transfer: #{e.message}"
	FileStorage::Response.new mid.not_nil!, "Not Ok", "Unexpected error: #{e.message}"
end

# TODO
# the client sent a download request
def hdl_download(request : FileStorage::DownloadRequest,
	user : User) : FileStorage::Response

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
			responses << hdl_download request, user
		when FileStorage::UploadRequest
			responses << hdl_upload request, user
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
