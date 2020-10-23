require "json"
require "uuid"
require "uuid/json"
require "openssl"

require "dodb"
require "base64"

require "./storage/*"

# private function
def digest(value : String)

	underlying_io = IO::Memory.new value
	buffer = Bytes.new(4096)

	io = OpenSSL::DigestIO.new underlying_io, "SHA256"
	io.read buffer

	io.digest.hexstring
end

# XXX TODO FIXME: architectural questions
#   Why keeping upload and download requests?
#   The server can be just for uploads, delegating downloads to HTTP,
#   but in environment without HTTP integration, this could still be relevant.

class FileStorage::Storage
	property db : DODB::CachedDataBase(TransferInfo)

	# Search file informations by their index, owner and tags.
	property db_by_filedigest : DODB::Index(TransferInfo)
	property db_by_owner      : DODB::Partition(TransferInfo)
	property db_by_tags       : DODB::Tags(TransferInfo)

	# Where to store data: files, users informations, files metadata.
	property root : String

	getter user_data               : DODB::DataBase(UserData)
	getter user_data_per_user      : DODB::Index(UserData)

	# FileStorage::Storage constructor takes a `root directory` as parameter
	# which is used to create 3 sub-dirs:
	# - files/ : actual files stored on the file-system
	# - meta/  : DODB TransferInfo
	# - users/ : DODB UserData (for later use: quotas, rights)

	def initialize(@root, reindex : Bool = false)
		@db = DODB::CachedDataBase(TransferInfo).new "#{@root}/meta"

		# Where to store uploaded files.
		FileUtils.mkdir_p "#{@root}/files"

		# Create indexes, partitions and tags objects.
		@db_by_filedigest   = @db.new_index     "filedigest", &.file_info.digest
		@db_by_owner        = @db.new_partition "owner",      &.owner.to_s
		@db_by_tags         = @db.new_tags      "tags",       &.file_info.tags

		@user_data            = DODB::DataBase(UserData).new "#{@root}/users"
		@user_data_per_user   = @user_data.new_index "uid",    &.uid.to_s

		if reindex
			@db.reindex_everything!
			@user_data.reindex_everything!
		end
	end

	# Path part of the URL.
	def get_path(file_digest : String)
		"/files/#{file_digest}"
	end

	# Path on the file-system.
	def get_fs_path(file_digest : String)
		"#{@root}#{get_path file_digest}"
	end

	# Reception of a file chunk.
	def write_chunk(message : FileStorage::Request::PutChunk, user : UserData)

		# We received a message containing a chunk of file.
		mid = message.mid
		mid ||= "no message id"

		# Get the transfer info from the db.
		transfer_info = @db_by_filedigest.get message.filedigest

		file_digest = transfer_info.file_info.digest

		if transfer_info.nil?
			raise "file not recorded"
		end

		if transfer_info.nil?
			# The user did not ask permission to upload the file (upload request).
			return FileStorage::Errors::FileDoesNotExist.new mid, file_digest
		end

		# Verify the user had a granted upload request.
		if transfer_info.owner != user.uid
			return FileStorage::Errors::ChunkUploadDenied.new mid, file_digest
		end

		# TODO: this should be dynamic (per file) in the future.
		chunk_size = FileStorage.message_buffer_size
		chunk_number = message.chunk.n
		data = Base64.decode message.data
		path = get_path file_digest

		# Verify that the chunk sent was really missing.
		if transfer_info.chunks.select do |v| v == chunk_number end.size == 1
			write_a_chunk file_digest, chunk_size, chunk_number, data
		else
			begin
				# Send the next remaining chunk to upload.
				chunks = transfer_info.chunks
				if chunks.size != 0
					next_chunk = transfer_info.chunks.sort.first
					return FileStorage::Errors::ChunkAlreadyUploaded.new mid, file_digest, next_chunk
				end
				# In case the file was completely uploaded already.
				return FileStorage::Errors::FileFullyUploaded.new mid, path
			rescue e
				Baguette::Log.error "error during transfer_info.chunks.sort.first"
				raise e
			end
		end

		remove_chunk_from_db transfer_info, chunk_number

		# TODO: verify the digest, if no more chunks.

		digest = transfer_info.file_info.digest
		FileStorage::Response::PutChunk.new mid, digest, chunk_number
	end

	# Provide a file chunk to the client.
	def read_chunk(message : FileStorage::Request::GetChunk, user : UserData)

		# We received a message containing a chunk of file.
		mid = message.mid
		mid ||= "no message id"

		file_digest   = message.filedigest
		# TODO: this should be dynamic (per file) in the future.
		chunk_size    = FileStorage.message_buffer_size
		chunk_number  = message.n
		transfer_info = @db_by_filedigest.get file_digest

		if transfer_info.nil?
			# The user is asking for an inexistant file.
			return FileStorage::Errors::FileDoesNotExist.new mid, file_digest
		end

		# Verify that the chunk is already present.
		if transfer_info.chunks.select do |v| v == chunk_number end.size != 0
			raise "non existent chunk or not yet uploaded"
		end

		# b64 data
		data = read_a_chunk file_digest, chunk_size, chunk_number
		b64_encoded_data = Base64.encode data

		# whole file digest
		digest = transfer_info.file_info.digest

		# about the transfered chunk
		chunk = Chunk.new chunk_number, transfer_info.file_info.nb_chunks, b64_encoded_data

		FileStorage::Response::GetChunk.new mid, digest, chunk, b64_encoded_data
	end

	# the client sent an upload request
	def upload(request : FileStorage::Request::Upload, user : UserData)

		mid = request.mid
		mid ||= "no message id"

		Baguette::Log.debug "hdl upload: mid=#{request.mid}"
		pp! request

		# The final path of the file.
		file_digest = request.file.digest
		path = get_path file_digest

		# TODO: verify the rights and quotas of the user
		# file_info attributes: name, size, nb_chunks, digest, tags

		# First: check if the file already exists.
		transfer_info = @db_by_filedigest.get? file_digest
		if transfer_info.nil?
			Baguette::Log.debug "new file: #{file_digest}"

			# In case file informations aren't already registered
			# which is normal at this point.
			@db << TransferInfo.new user.uid, request.file
		else
			Baguette::Log.debug "file already upload (at least partially): #{file_digest}"
			# File information already exists, request may be duplicated,
			# in this case: ignore the upload request.
			begin
				chunks = transfer_info.chunks
				if chunks.size != 0
					next_chunk = chunks.sort.first
					return FileStorage::Errors::FileExists.new mid, path, next_chunk
				end
				# In case the file was completely uploaded already.
				return FileStorage::Errors::FileFullyUploaded.new mid, path
			rescue e
				Baguette::Log.error "error at transfer_info.chunks.sort.first in upload"
				raise e
			end
		end

		# TODO: store upload request in UserData?

		FileStorage::Response::Upload.new request.mid, path
	end

	# The client sent a download request.
	def download(request : FileStorage::Request::Download, user : UserData)

		mid = request.mid
		mid ||= "no message id"
		Baguette::Log.debug "hdl download: mid=#{mid}"

		unless (file_digest = request.filedigest).nil?
			unless (file_transfer = @db_by_filedigest.get? file_digest).nil?
				# The file exists.
				# TODO: verify rights here.

				# This is acceptation.
				# Return some useful values: number of chunks.
				return FileStorage::Response::Download.new mid, file_transfer.file_info
			else
				return FileStorage::Errors::GenericError.new mid, "Unknown file digest: #{file_digest}"
			end
		end

		# TODO: search a file by its name and tags

		# TODO: store download request in UserData?

		# Should have returned by now: file wasn't found.
		FileStorage::Errors::GenericError.new mid, "File not found with provided parameters."
	end

	# Entry point for request management
	# Each request should have a response.
	# Then, responses are sent in a single message.
#	def requests(requests : Array(FileStorage::Request),
#		user : UserData,
#		event : IPC::Event::Message) : Array(FileStorage::Response)
#
#		Baguette::Log.debug "hdl request"
#		responses = Array(FileStorage::Response | FileStorage::Errors).new
#
#		requests.each do |request|
#			case request
#			when FileStorage::DownloadRequest
#				responses << download request, user
#			when FileStorage::UploadRequest
#				responses << upload request, user
#			else
#				raise "request not understood"
#			end
#
#		end
#
#		responses
#	end

	def read_a_chunk(file_digest : String, chunk_size : Int32, chunk_number : Int32)
		offset = chunk_number * chunk_size
		buffer_data = Bytes.new chunk_size

		path = get_fs_path file_digest
		real_size = 0
		File.open(path, "rb") do |file|
			file.seek offset
			real_size = file.read buffer_data
		end

		buffer_data[0..real_size-1]
	end

	def remove_chunk_from_db(transfer_info : TransferInfo, chunk_number : Int32)
		transfer_info.chunks.delete chunk_number
		@db_by_filedigest.update transfer_info.file_info.digest, transfer_info
	end

	def write_a_chunk(digest : String,
		chunk_size : Int32,
		chunk_number : Int32,
		data : Bytes)

		# storage: @root/files/digest
		path = get_fs_path digest

		# Create file if non existant
		File.open(path, "a+") do |file|
		end

		# Write in it
		File.open(path, "ab") do |file|
			offset = chunk_number * chunk_size
			file.seek(offset, IO::Seek::Set)
			file.write data
		end
	end
end
