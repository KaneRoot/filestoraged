
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

	def transfer(file_info : FileInfo, count, bindata)
		request = FileStorage::Request::PutChunk.new file_info, count, bindata
		send request

		response = parse_message [ FileStorage::Response::PutChunk, FileStorage::Response::Error ], read

		case response
		when FileStorage::Response::PutChunk
		when FileStorage::Response::Error
			raise "File chunk was not transfered: #{response.reason}"
		end

		response
	end

	def download(filedigest = nil, name = nil, tags = nil)
		request = FileStorage::Request::Download.new filedigest, name, tags
		send request

		response = parse_message [ FileStorage::Response::Download, FileStorage::Response::Error ], read

		case response
		when FileStorage::Response::Download
		when FileStorage::Response::Error
			raise "Download request denied: #{response.reason}"
		end

		response
	end

	def upload(token : String)
		request = FileStorage::Request::Upload.new token
		send request

		response = parse_message [ FileStorage::Response::Upload, FileStorage::Response::Error ], read

		case response
		when FileStorage::Response::Upload
		when FileStorage::Response::Error
			raise "Upload request failed: #{response.reason}"
		end

		response
	end
end
