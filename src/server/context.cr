
require "dodb"
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
	property file_info : FileStorage::FileInfo
	property chunks : Array(Int32)

	def initialize(@owner, @file_info)
		@chunks = [0...@file_info.nb_chunks]
	end
end

class Context
	class_property service_name        = "filestorage"
	class_property storage_directory   = "./storage"
	class_property file_info_directory = "./file-infos"

	class_property db = DODB::DataBase(TransferInfo).new @@file_info_directory

	# search file informations by their index, owner and tags
	class_property db_by_filedigest : DODB::Index(TransferInfo) = @@db.new_index "filedigest", &.file_info.digest
	class_property db_by_owner : DODB::Partition(TransferInfo)  = @@db.new_partition "owner",  &.owner.to_s
	class_property db_by_tags : DODB::Tags(TransferInfo)        = @@db.new_tags "tags",        &.file_info.tags

	def self.db_reconnect
		# In case file_info_directory changes: database reinstanciation

		@@db = DODB::DataBase(TransferInfo).new @@file_info_directory

		# recreate indexes, partitions and tags objects, too
		@@db_by_filedigest = @@db.new_index     "filedigest", &.file_info.digest
		@@db_by_owner      = @@db.new_partition "owner",      &.owner.to_s
		@@db_by_tags       = @@db.new_tags      "tags",       &.file_info.tags
	end

	# list of connected users (fd => uid)
	class_property connected_users = Hash(Int32, Int32).new

	# users_status: keep track of the users' status even if they are
	# disconnected, allowing the application to handle connection problems
	class_property users_status = Hash(Int32, User).new

	class_property service : IPC::Service? = nil
end
