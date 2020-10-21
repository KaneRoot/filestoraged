require "dodb"
require "json"
require "../filestorage.cr"

# this is a copy of User and TransferInfo classes from src/server/context.cr
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
	property chunks : Hash(Int32, Bool)

	def initialize(@owner, @file_info)
		@chunks = Hash(Int32, Bool).new
		@file_info.nb_chunks.times do |n|
			@chunks[n] = false
		end
	end
end


file_info_directory = "./file-infos"

def init_db(file_info_directory : String)
	db = DODB::DataBase(TransferInfo).new file_info_directory

	# search file informations by their index, owner and tags
	pp! db_by_filedigest = db.new_index     "filedigest", &.file_info.digest
	pp! db_by_owner      = db.new_partition "owner",      &.owner.to_s
	pp! db_by_tags       = db.new_tags      "tags",       &.file_info.tags.not_nil!

	db
end

db = init_db file_info_directory
pp! db
