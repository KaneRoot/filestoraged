require "ipc"

class FileStorage::Client < IPC::Client
	property auth_token : String

	def initialize(@auth_token, service_name = "filestorage")
		super service_name
	end

	# TODO: parse_message should raise exception if response not anticipated
	def parse_message(expected_messages, message)
		em = Array(IPC::JSON.class).new
		expected_messages.each do |e|
			em << e
		end
		em << FileStorage::Errors::GenericError
		em << FileStorage::Errors::Authorization
		em << FileStorage::Errors::ChunkAlreadyUploaded
		em << FileStorage::Errors::ChunkUploadDenied
		em << FileStorage::Errors::FileExists
		em << FileStorage::Errors::FileDoesNotExist
		em << FileStorage::Errors::FileFullyUploaded
		em.parse_ipc_json message
	end
end

class FileStorage::Client < IPC::Client
	def login
		request = FileStorage::Request::Login.new @auth_token
		send_now @server_fd.not_nil!, request
		parse_message [ FileStorage::Response::Login ], read
	end

	# Helper function.
	def get_file_info(file_path : String)
		file_info : FileStorage::FileInfo
		file = File.open(file_path)
		file_info = FileStorage::FileInfo.new file
		file.close
		file_info.not_nil!
	end

	def transfer(file_path : String)
		file_info = get_file_info file_path

		File.open(file_path) do |file|
			buffer_size = FileStorage.message_buffer_size

			buffer = Bytes.new buffer_size
			counter = 0
			size = 0

			while (size = file.read(buffer)) > 0
				# transfer message = file_info, chunk count, data (will be base64'd)
				transfer_message = FileStorage::Request::PutChunk.new file_info,
					counter,
					buffer[0 ... size]

				send_now @server_fd.not_nil!, transfer_message
				counter += 1

				buffer = Bytes.new buffer_size

				# Check for the response
				response = parse_message [ FileStorage::Response::PutChunk ], read

				if response.responds_to? :mid
					if response.mid != transfer_message.mid
						raise "request and response mid !=: #{response.mid} != #{transfer_message.mid}"
					else
						pp! response
					end
				else
					raise "response doesn't have mid"
				end
			end
		end
	end

	def download(filedigest = nil, name = nil, tags = nil)
		request = FileStorage::Request::Download.new filedigest, name, tags
		send_now @server_fd.not_nil!, request
		parse_message [ FileStorage::Response::Download ], read
	end

	def get_chunks(dl_response : FileStorage::Response::Download, path : String = ".")
		file_path = "#{path}/#{dl_response.file_info.name}"
		Baguette::Log.debug "Getting #{file_path}"

		digest = dl_response.file_info.digest
		buffer_size = FileStorage.message_buffer_size

		counter = 0
		size = 0

		while counter < dl_response.file_info.nb_chunks
			Baguette::Log.debug "Getting #{file_path}: chunk #{counter+1}/#{dl_response.file_info.nb_chunks}"
			get_chunk_message = FileStorage::Request::GetChunk.new digest, counter
			send_now @server_fd.not_nil!, get_chunk_message
			response = parse_message [ FileStorage::Response::GetChunk ], read
			# TODO: write the file
			pp! response

			case response
			when FileStorage::Response::GetChunk
				b64_decoded_data = Base64.decode response.data
				write_chunk file_path, buffer_size, response.chunk.n, b64_decoded_data
			else
				Baguette::Log.error "#{response}"
				raise "wrong response: #{response}"
			end
			counter += 1
		end
	end

	# Reception of a file chunk.
	def write_chunk(file_path : String,
			chunk_size : Int32,
			offset : Int32,
			data : Bytes
		)

		pp! file_path, chunk_size, offset, data.size

		# Create the file if non existant.
		File.open(file_path, "a+") do |file|
			file.seek (offset * chunk_size)
			file.write data
		end
	end


	def upload(file : String)
		file_info : FileStorage::FileInfo
		File.open(file) do |f|
			file_info = FileStorage::FileInfo.new f
			request = FileStorage::Request::Upload.new file_info
			send_now @server_fd.not_nil!, request
		end

		parse_message [ FileStorage::Response::Upload ], read
	end
end
