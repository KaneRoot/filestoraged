require "ipc"
require "json"

class JSONIPC
	include JSON::Serializable

	getter       type = -1
	class_getter type = -1

	property     id   : JSON::Any?

	def handle(service : IPC::Service, event : IPC::Event::Events)
		raise "unimplemented"
	end

	macro request(id, type, &block)
		class {{id}} < ::JSONIPC
			include JSON::Serializable

			@@type = {{type}}
			def type
				@@type
			end

			{{yield}}
		end
	end
end

class IPC::Connection
	def send(request : JSONIPC)
		send request.type.to_u8, request.to_json
	end
end

class FileStorage
	class_getter requests  = [] of JSONIPC.class
	class_getter responses = [] of JSONIPC.class
	class_getter errors    = [] of JSONIPC.class
end

class FileStorage::Client < IPC::Client
	def initialize
		initialize "filestorage"
	end
end

def parse_message(requests : Array(JSONIPC.class), message : IPC::Message) : JSONIPC?
	request_type = requests.find &.type.==(message.utype)

	payload = String.new message.payload

	if request_type.nil?
		raise "invalid request type (#{message.utype})"
	end

	request_type.from_json payload
end


require "../common/requests/client.cr"
require "../common/requests/login.cr"
require "../common/requests/transfer.cr"
require "../common/requests/upload.cr"
require "../common/requests/errors.cr"
require "../common/requests/download.cr"

# require "../common/requests/*"
