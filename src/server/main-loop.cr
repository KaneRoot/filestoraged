
Context.service = IPC::Service.new Context.service_name

Context.service.not_nil!.loop do |event|
	case event
	when IPC::Event::Timer
		puts "#{CORANGE}IPC::Event::Timer#{CRESET}"

	when IPC::Event::Connection
		puts "#{CBLUE}IPC::Event::Connection: #{event.connection.fd}#{CRESET}"

	when IPC::Event::Disconnection
		puts "#{CBLUE}IPC::Event::Disconnection: #{event.connection.fd}#{CRESET}"

		Context.connected_users.select! do |fd, uid|
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

		# The first message sent to the server has to be the AuthenticationMessage.
		# Users sent their token (JWT) to authenticate themselves.
		# The token contains the user id, its login and a few other parameters.
		# (see the authd documentation).
		# TODO: for now, the token is replaced by a hardcoded one, for debugging

		mtype = FileStorage::MessageType.new event.message.type.to_i32

		# First, the user has to be authenticated unless we are receiving its first message
		userid = Context.connected_users[event.connection.fd]?

		# if the user is not yet connected but does not try to perform authentication
		if ! userid && mtype != FileStorage::MessageType::Authentication
			# TODO: replace this with an Error message?
			mid = "no message id"
			response = FileStorage::Message::Response.new mid, "Not OK", "Action on non connected user"
			event.connection.send FileStorage::MessageType::Response.to_u8, response.to_json
		end

		case mtype
		when .authentication?
			puts "Receiving an authentication message"
			# 1. test if the client is already authenticated
			if userid
				user = Context.users_status[userid]
				raise "Authentication message while the user was already connected: this should not happen"
			else
				puts "User is not currently connected"
				hdl_authentication event
			end
		when .upload_request?
			puts "Upload request"
			request = FileStorage::Message::UploadRequest.from_json(
				String.new event.message.payload
			)
			response = hdl_upload request, Context.users_status[userid], event

			event.connection.send FileStorage::MessageType::Response.to_u8, response.to_json
			raise "not implemented yet"
		when .download_request?
			puts "Download request"
			request = FileStorage::Message::DownloadRequest.from_json(
				String.new event.message.payload
			)
			response = hdl_download request, Context.users_status[userid], event

			event.connection.send FileStorage::MessageType::Response.to_u8, response.to_json
			raise "not implemented yet"
		when .response?
			puts "Response message"
			raise "not implemented yet"
		when .responses?
			puts "Responses message"
			raise "not implemented yet"
		when .error?
			puts "Error message"
			raise "not implemented yet"
		when .transfer?
			# throw an error if the user isn't recorded
			unless user = Context.users_status[userid]?
				raise "The user isn't recorded in the users_status structure"
			end

			transfer = FileStorage::Message::Transfer.from_json(
				String.new event.message.payload
			)
			response = hdl_transfer transfer, Context.users_status[userid], event

			event.connection.send FileStorage::MessageType::Response.to_u8, response.to_json
		end
	else
		raise "Event type not supported."
	end
rescue e
	puts "A problem occured : #{e.message}"
end
