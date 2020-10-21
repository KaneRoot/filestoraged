class FileStorage::Errors
	IPC::JSON.message GenericError, 200 do
		property mid    : String
		property reason : String
		def initialize(@mid, @reason)
		end
	end
	FileStorage.errors << GenericError

	IPC::JSON.message Authorization, 201 do
		property mid    : String
		property reason : String
		def initialize(@mid, @reason = "authorization")
		end
	end
	FileStorage.errors << Authorization

	# When uploading a chunk already present in the DB.
	IPC::JSON.message ChunkAlreadyUploaded, 202 do
		property mid        : String
		property reason     = "Chunk already present"
		property filedigest : String
		property next_chunk : Int32

		def initialize(@mid, @filedigest, @next_chunk)
		end
	end
	FileStorage.errors << ChunkAlreadyUploaded

	# You upload a chunk, but you are not the owner of the file.
	IPC::JSON.message ChunkUploadDenied, 203 do
		property mid        : String
		property reason     = "This file is not yours"
		property filedigest : String

		def initialize(@mid, @filedigest)
		end
	end
	FileStorage.errors << ChunkUploadDenied

	# When uploading a file already present in the DB.
	IPC::JSON.message FileExists, 204 do
		property mid        : String
		property reason     = "file already present"
		property path       : String
		property next_chunk : Int32

		def initialize(@mid, @path, @next_chunk)
		end
	end
	FileStorage.errors << FileExists

	# When transfering a chunk for an inexistent file.
	IPC::JSON.message FileDoesNotExist, 205 do
		property mid        : String
		property reason     = "file does not exist"
		property filedigest : String

		def initialize(@mid, @filedigest)
		end
	end
	FileStorage.errors << FileDoesNotExist

	# When a file was already fully uploaded.
	IPC::JSON.message FileFullyUploaded, 206 do
		property mid        : String
		property reason     = "file already uploaded fully"
		property path       : String

		def initialize(@mid, @path)
		end
	end
	FileStorage.errors << FileFullyUploaded

	IPC::JSON.message FileTooBig, 207 do
		property mid        : String
		property reason     = "file too big"
		property limit      : UInt64

		def initialize(@mid, @limit)
		end
	end
	FileStorage.errors << FileTooBig
end
