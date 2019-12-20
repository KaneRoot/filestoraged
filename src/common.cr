require "uuid"

enum MessageType
	Error
	AuthenticationMessage
	Response
	Transfer
end

# For now, upload and download are sequentials.
# In a future version, we will be able to send
# arbitrary parts of each file.

class Token
	JSON.mapping({
		uid: Int32,
		login: String
	})
	
	def initialize(@uid, @login)
	end
end

# Who knows, maybe someday we will be on UDP, too.
#class SHA256
#	JSON.mapping({
#		chunk: Slice(UInt8)
#	})
#end


# A file has a name, a size and tags.
class FileInfo
	JSON.mapping({
		name: String,
		size: UInt64,
		# list of SHA256, if we are on UDP
		# chunks: Array(SHA256),
		tags: Array(String)?
	})

	# debugging constructor
	def initialize(@name, @size, @tags = nil)
		# If on UDP
		# @chunks = Array(SHA256).new
		# arbitrary values here
	end

	def initialize(file : File, @tags = nil)
		@name = File.basename file.path
		@size = file.size
	end
end

class Request
end

class UploadRequest < Request
	property files_to_upload : Array(FileInfo)

	def initialize(@files_to_upload)
	end
end


# WIP
class DownloadRequest < Request
	property names : Array(String)?,
	property tags : Array(String)?

	def initialize(@names = nil, @tags = nil)
	end
end

class AuthenticationMessage
	JSON.mapping({
		mid: String,
		token: Token,
		requests: Array(Requests)
	})

	def initialize(@token, @files, @tags = nil)
		@mid = UUID.random.to_s
	end
end

class Response
	JSON.mapping({
		mid: String,
		response: String,
		reason: String?
	})

	def initialize(@mid, @response, @reason = nil)
	end
end

class TransferMessage
	JSON.mapping({
		mid: String,
		chunk: String,
		data: Slice(UInt8)
	})

	def initialize(@chunk, @data)
		@mid = UUID.random.to_s
	end
end
