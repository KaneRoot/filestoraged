class FileStorage::Request
	JSONIPC.request Transfer, 40 do
		property mid        : String   # autogenerated
		property filedigest : String   # SHA256 digest of the entire file
		# Chunk:
		# - n      : Int32  => chunk number
		# - on     : Int32  => number of chunks
		# - digest : String => 1024-byte data in base64 format
		property chunk      : Chunk    # For now, just the counter in a string
		property data       : String   # base64 slice
		def initialize(file_info : FileInfo, count, bindata)
			# count: chunk number

			@filedigest = file_info.digest
			@data = Base64.encode bindata
			@chunk = FileStorage::Chunk.new count, file_info.nb_chunks - 1, @data
			@mid = UUID.random.to_s
		end

		def handle(filestoraged : FileStorage::Service, event : IPC::Event::Events)
			user = filestoraged.get_logged_user event

			raise Exception.new "unauthorized" if user.nil?

			# FIXME: Maybe this should be moved to FileStorage::Service
			fd = event.connection.fd

			user_data = filestoraged.get_user_data user.uid

			filestoraged.storage.transfer self, user_data
		rescue e
			return Response::Error.new @mid, "unauthorized"
		end
	end
	FileStorage.requests << Transfer
end

class FileStorage::Client
	def transfer(file_info : FileInfo, count, bindata)
		request = FileStorage::Request::Transfer.new file_info, count, bindata
		send request

		response = parse_message [ FileStorage::Response::Transfer, FileStorage::Response::Error ], read

		case response
		when FileStorage::Response::Transfer
		when FileStorage::Response::Error
			raise "File chunk was not transfered: #{response.reason}"
		end

		response
	end
end


class FileStorage::Response
	JSONIPC.request Transfer, 40 do
		property mid : String
		def initialize(@mid)
		end
	end
end