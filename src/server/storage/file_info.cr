
# For now, upload and download are sequentials.
# In a future version, we will be able to send
# arbitrary parts of each file.

	# Who knows, maybe someday we will be on UDP, too.
	#class SHA256
	#	JSON.mapping({
	#		chunk: Slice(UInt8)
	#	})
	#end

module FileStorage

	# 1 MB read buffer, on-disk
	def self.file_reading_buffer_size
		1_000_000
	end

	# 1 KB message data buffer, on-network
	def self.message_buffer_size
		1_000
	end

	# private function
	def self.data_digest(data : Bytes)
		digest = OpenSSL::Digest.new "sha256"
		digest.update data
		digest.hexfinal
	end

	# private function
	def self.file_digest(file : File)
		# 1M read buffer
		buffer = Bytes.new(1_000_000)

		io = OpenSSL::DigestIO.new(file, "SHA256")
		while io.read(buffer) > 0 ; end

		io.digest.hexstring
	end
end

class FileStorage::Chunk
	include JSON::Serializable

	property n      : Int32   # chunk's number
	property on     : Int32   # number of chunks
	property digest : String  # digest of the current chunk

	def initialize(@n, @on, data)
		@digest = FileStorage.data_digest data.to_slice
	end
end

# A file has a name, a size and tags.
class FileStorage::FileInfo
	include JSON::Serializable

	property name      : String
	property size      : UInt64
	property nb_chunks : Int32
	property digest    : String

	# list of SHA256, if we are on UDP
	# chunks: Array(SHA256),
	property tags : Array(String)

	def initialize(file : File, tags = nil)
		@name = File.basename file.path
		@size = file.size
		@digest = FileStorage.file_digest file
		@nb_chunks = (@size / FileStorage.message_buffer_size).ceil.to_i
		@tags = tags || [] of String
	end
end
