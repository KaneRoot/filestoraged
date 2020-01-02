
# keep track of connected users and their requests
# TODO: requests should be handled concurrently
class User
	property uid : Int32
	property token : FileStorage::Token
	property requests : Array(FileStorage::Message::Request)?

	def initialize(@token, @requests = nil)
		@uid = token.uid
	end
end

class Context
	class_property service_name      = "filestorage"
	class_property storage_directory = "./storage"

	# list of connected users (fd => uid)
	class_property connected_users = Hash(Int32, Int32).new

	# users_status: keep track of the users' status even if they are
	# disconnected, allowing the application to handle connection problems
	class_property users_status = Hash(Int32, User).new

	class_property service : IPC::Service? = nil
end
