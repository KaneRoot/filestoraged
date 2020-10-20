require "ipc"
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

require "../common/requests/client.cr"
require "../common/requests/login.cr"
require "../common/requests/transfer.cr"
require "../common/requests/upload.cr"
require "../common/requests/errors.cr"
require "../common/requests/download.cr"

# require "../common/requests/*"
