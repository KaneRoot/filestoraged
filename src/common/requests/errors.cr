class FileStorage::Errors
	JSONIPC.request GenericError, 200 do
		property mid    : String
		property reason : String
		def initialize(@mid, @reason)
		end
	end
	FileStorage.errors << GenericError

	JSONIPC.request Authorization, 201 do
		property mid    : String
		property reason : String
		def initialize(@mid, @reason = "authorization")
		end
	end
	FileStorage.errors << Authorization

	# When uploading a chunk already present in the DB.
	JSONIPC.request ChunkAlreadyUploaded, 202 do
		property mid        : String
		property reason     = "Chunk already present"
		property filedigest : String
		property next_chunk : Int32

		def initialize(@mid, @filedigest, @next_chunk)
		end
	end
	FileStorage.errors << ChunkAlreadyUploaded

	# You upload a chunk, but you are not the owner of the file.
	JSONIPC.request ChunkUploadDenied, 203 do
		property mid        : String
		property reason     = "This file is not yours"
		property filedigest : String

		def initialize(@mid, @filedigest)
		end
	end
	FileStorage.errors << ChunkUploadDenied

	# When uploading a file already present in the DB.
	JSONIPC.request FileExists, 204 do
		property mid        : String
		property reason     = "file already present"
		property filedigest : String

		def initialize(@mid, @filedigest)
		end
	end
	FileStorage.errors << FileExists

	# When transfering a chunk for an inexistent file.
	JSONIPC.request FileDoesNotExist, 205 do
		property mid        : String
		property reason     = "file does not exist"
		property filedigest : String

		def initialize(@mid, @filedigest)
		end
	end
	FileStorage.errors << FileDoesNotExist
end
