require "ipc"
require "ipc/json"
require "json"

class IPC::Context
	def send(fd : Int32, request : IPC::JSON)
		send fd, request.type.to_u8, request.to_json
	end
end

module FileStorage
	class_getter requests  = [] of IPC::JSON.class
	class_getter responses = [] of IPC::JSON.class
	class_getter errors    = [] of IPC::JSON.class
end

class FileStorage::Client < IPC::Client
	def initialize
		initialize "filestorage"
	end
end

require "../requests/login.cr"
require "../requests/transfer.cr"
require "../requests/upload.cr"
require "../requests/errors.cr"
require "../requests/download.cr"

# require "../requests/*"
