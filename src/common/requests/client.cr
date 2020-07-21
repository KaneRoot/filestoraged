require "ipc"

class FileStorage::Client < IPC::Client
	property auth_token : String

	def initialize(@auth_token, service_name = "filestorage")
		super service_name
	end

	def login
		request = FileStorage::Request::Login.new auth_token
		send @server_fd.not_nil!, request

		response = parse_message [
			FileStorage::Response::Login,
			FileStorage::Errors::GenericError
			], read

		if response.responds_to? :mid
			if request.mid != response.mid
				raise "mid from response != request"
			end
		else
			raise "response doen't even have mid"
		end

		response
	end

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

				send @server_fd.not_nil!, transfer_message
				counter += 1

				buffer = Bytes.new buffer_size

				# Check for the response
				response = parse_message [
						FileStorage::Response::PutChunk,
						FileStorage::Errors::GenericError
					], read

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
		send @server_fd.not_nil!, request

		response = parse_message [
			FileStorage::Response::Download,
			FileStorage::Errors::GenericError
			], read

		response
	end

	def upload(file : String)
		file_info : FileStorage::FileInfo
		File.open(file) do |f|
			file_info = FileStorage::FileInfo.new f
			request = FileStorage::Request::Upload.new file_info
			send @server_fd.not_nil!, request
		end

		response = parse_message [
			FileStorage::Response::Upload,
			FileStorage::Errors::GenericError
			], read

		response
	end
end
