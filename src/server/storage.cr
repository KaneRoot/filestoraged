require "json"
require "uuid"
require "uuid/json"
require "openssl"

require "dodb"
require "base64"

require "../common/utils"

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
#   The server can be just for uploads, delegating downloads to HTTP.
#   In environment without HTTP integration, this could still be pertinent.

class FileStorage::Storage
	property db : DODB::DataBase(TransferInfo)

	# Search file informations by their index, owner and tags.
	property db_by_filedigest : DODB::Index(TransferInfo)
	property db_by_owner      : DODB::Partition(TransferInfo)
	property db_by_tags       : DODB::Tags(TransferInfo)

	def initialize(storage_directory, file_info_directory)
		@db = DODB::DataBase(TransferInfo).new @file_info_directory

		# Create indexes, partitions and tags objects.
		@db_by_filedigest   = @db.new_index     "filedigest", &.file_info.digest
		@db_by_owner        = @db.new_partition "owner",      &.owner.to_s
		@db_by_tags         = @db.new_tags      "tags",       &.file_info.tags
	end

	# Reception of a file chunk.
	def transfer(message : FileStorage::Transfer, user : User) : FileStorage::Response

		# We received a message containing a chunk of file.
		mid = message.mid
		mid ||= "no message id"

		# Get the transfer info from the db
		transfer_info = @db_by_filedigest.get message.filedigest

		if transfer_info.nil?
			# The user has to send an upload request before sending anything.
			# If not the case, it should be discarded.
			raise "file not recorded"
		end

		chunk_number = message.chunk.n

		data = Base64.decode message.data

		# TODO: verify that the chunk sent was really missing.
		if transfer_info.chunks.select(chunk_number).size > 0
			write_a_chunk user.uid.to_s, transfer_info.file_info, chunk_number, data
		else
			raise "non existent chunk or already uploaded"
		end

		remove_chunk_from_db transfer_info, chunk_number

		# TODO: verify the digest, if no more chunks.

		FileStorage::Response::Transfer.new mid
	rescue e
		puts "Error handling transfer: #{e.message}"
		FileStorage::Response.new mid.not_nil!, "Not Ok", "Unexpected error: #{e.message}"
	end

	# the client sent an upload request
	def upload(request : FileStorage::Request::Upload, user : User) : FileStorage::Response

		mid = request.mid
		mid ||= "no message id"

		puts "hdl upload: mid=#{request.mid}"
		pp! request

		# TODO: verify the rights and quotas of the user
		# file_info attributes: name, size, nb_chunks, digest, tags

		# First: check if the file already exists
		transfer_info = @db_by_filedigest.get? request.file.digest
		if transfer_info.nil?
			# In case file informations aren't already registered
			# which is normal at this point
			transfer_info = TransferInfo.new user.uid, request.file
			@db << transfer_info
		else
			# File information already exists, request may be duplicated
			# In this case: ignore the upload request
		end

		FileStorage::Response::Upload.new request.mid
	rescue e
		puts "Error handling transfer: #{e.message}"
		FileStorage::Response.new mid.not_nil!, "Not Ok", "Unexpected error: #{e.message}"
	end

	# TODO
	# The client sent a download request.
	def download(request : FileStorage::DownloadRequest, user : User) : FileStorage::Response

		puts "hdl download: mid=#{request.mid}"
		pp! request

		FileStorage::Response::Download.new request.mid
	end


	# Entry point for request management
	# Each request should have a response.
	# Then, responses are sent in a single message.
	def requests(requests : Array(FileStorage::Request),
		user : User,
		event : IPC::Event::Message) : Array(FileStorage::Response)

		puts "hdl request"
		responses = Array(FileStorage::Response).new

		requests.each do |request|
			case request
			when FileStorage::DownloadRequest
				responses << download request, user
			when FileStorage::UploadRequest
				responses << upload request, user
			else
				raise "request not understood"
			end

			puts
		end

		responses
	end
end
