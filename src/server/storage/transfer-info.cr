
class TransferInfo
	include JSON::Serializable

	property owner : Int32
	property file_info : FileStorage::FileInfo
	property chunks : Array(Int32)

	def initialize(@owner, @file_info)
		@chunks = (0...@file_info.nb_chunks).to_a
	end
end

