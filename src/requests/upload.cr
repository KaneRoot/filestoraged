
class FileStorage::Request
	IPC::JSON.message Upload, 20 do
		property mid  : String     # autogenerated
		property file : FileInfo
		def initialize(@file : FileInfo)
			@mid = UUID.random.to_s
		end

		def handle(filestoraged : FileStorage::Service, event : IPC::Event)
			user = filestoraged.get_logged_user event

			raise NotLoggedException.new if user.nil?

			raise FileTooBig.new if @file.size > filestoraged.max_file_size

			# FIXME: Maybe this should be moved to FileStorage::Service
			fd = event.fd

			user_data = filestoraged.get_user_data user.uid

			filestoraged.storage.upload self, user_data
		end
	end
	FileStorage.requests << Upload
end

class FileStorage::Response
	IPC::JSON.message Upload, 20 do
		property mid : String
		property path : String
		def initialize(@mid, @path)
		end
	end
	FileStorage.responses << Upload

#	IPC::JSON.message Responses, 100 do
#		property mid       : String
#		property responses : Array(Response | Errors)   # a response for each request
#		property response  : String
#		property reason    : String?
#
#		def initialize(@mid, @response, @responses, @reason = nil)
#		end
#	end
end
