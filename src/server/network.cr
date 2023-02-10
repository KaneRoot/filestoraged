require "ipc"
require "ipc/json"
require "json"

class IPC
	def schedule(fd : Int32, request : IPC::JSON)
		m = IPCMessage::TypedMessage.new request.type.to_u8, request.to_json
		schedule fd, m
	end
end

module FileStorage
	class_getter requests  = [] of IPC::JSON.class
	class_getter responses = [] of IPC::JSON.class
	class_getter errors    = [] of IPC::JSON.class
end

require "../requests/login.cr"
require "../requests/transfer.cr"
require "../requests/upload.cr"
require "../requests/errors.cr"
require "../requests/download.cr"
