class FileStorage::Request
	JSONIPC.request PutChunk, 40 do
		property mid        : String   # autogenerated
		property filedigest : String   # SHA256 digest of the entire file
		# Chunk:
		# - n      : Int32  => chunk number
		# - on     : Int32  => number of chunks
		# - digest : String => digest of the chunk
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

			filestoraged.storage.write_chunk self, user_data
		rescue e
			return Errors::GenericError.new @mid, e.to_s
		end
	end
	FileStorage.requests << PutChunk

	JSONIPC.request GetChunk, 41 do
		property mid        : String   # autogenerated
		property filedigest : String   # SHA256 digest of the entire file
		property n          : Int32    # chunk number

		def initialize(@filedigest, @n)
			@mid = UUID.random.to_s
		end

		def handle(filestoraged : FileStorage::Service, event : IPC::Event::Events)
			user = filestoraged.get_logged_user event

			raise Exception.new "unauthorized" if user.nil?

			# FIXME: Maybe this should be moved to FileStorage::Service
			fd = event.connection.fd

			user_data = filestoraged.get_user_data user.uid

			filestoraged.storage.read_chunk self, user_data
		rescue e
			return Errors::GenericError.new @mid, e.to_s
		end
	end
	FileStorage.requests << GetChunk
end

class FileStorage::Response
	JSONIPC.request PutChunk, 40 do
		property mid : String
		property file_digest : String
		property n : Int32    # chunk number
		def initialize(@mid, @file_digest, @n)
		end
	end

	JSONIPC.request GetChunk, 41 do
		property mid : String
		property file_digest : String
		# Chunk:
		# - n      : Int32  => chunk number
		# - on     : Int32  => number of chunks
		# - digest : String => digest of the chunk
		property chunk : Chunk  # Currently: info about the chunk
		property data  : String # base64 slice
		def initialize(@mid, @file_digest, @chunk, @data)
		end
	end
end
