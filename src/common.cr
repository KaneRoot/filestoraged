require "uuid"

class Token
	JSON.mapping({
		uid: Int32,
		login: String
	})
	
	def initialize(@uid, @login)
	end
end

class FileInfo
	JSON.mapping({
		name: String,
		size: UInt32,
		tags: Array(String)?
	})

	def initialize(@name, @size, @tags = nil)
	end

	def initialize(file : File, @tags = nil)
		@name = file.basename
		@size = file.size
	end
end

class AuthenticationMessage
	JSON.mapping({
		mid: String,
		token: Token,
		files: Array(FileInfo),
		tags: Array(String)?
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

class Transfer
	JSON.mapping({
		mid: String,
		chunk: String,
		data: Slice(UInt8)
	})

	def initialize(@chunk, @data)
		@mid = UUID.random.to_s
	end
end
