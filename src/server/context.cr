
require "json"

# keep track of connected users and their requests
# TODO: requests should be handled concurrently
class User
	property uid : Int32
	property token : FileStorage::Token
	property uploads : Array(FileStorage::UploadRequest)
	property downloads : Array(FileStorage::DownloadRequest)

	def initialize(@token,
		@uploads = Array(FileStorage::UploadRequest).new,
		@downloads = Array(FileStorage::DownloadRequest).new)
		@uid = token.uid
	end
end

class TransferInfo
	include JSON::Serializable

	property owner : Int32
	property file_info : FileInfo
	property chunks : Hash(Int32, Bool)

	def initialize(@owner, @file_info)
		@chunks = Hash(Int32, Bool).new
		@file_info.nb_chunks.times do |n|
			@chunks[n] = false
		end
	end
end

class Context
	class_property service_name      = "filestorage"
	class_property storage_directory = "./storage"
	class_property file_info_directory = "./file-infos"

	class_property db : DODB::DataBase(TransferInfo) = self.init_db

	def init_db
		@@db = DODB::DataBase(TransferInfo).new @@file_info_directory

		# init index, partitions and tags
		Context.db.new_index     "filedigest", &.file_info.digest
		Context.db.new_partition "owner",      &.owner
		Context.db.new_tags      "tags",       &.tags
	end

	# list of connected users (fd => uid)
	class_property connected_users = Hash(Int32, Int32).new

	# users_status: keep track of the users' status even if they are
	# disconnected, allowing the application to handle connection problems
	class_property users_status = Hash(Int32, User).new

	class_property service : IPC::Service? = nil
end
