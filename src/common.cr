
require "uuid"

class Token
	JSON.mapping({
		uid: Int32,
		login: String
	})
	
	def initialize(@uid, @login)
	end
end

class AuthenticationMessage
	JSON.mapping({
		mid: String,
		token: Token
	})

	def initialize(@token)
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
