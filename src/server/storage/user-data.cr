require "json"
require "uuid"
require "uuid/json"


# Keep track of connected users and their requests.
# TODO: requests should be handled concurrently.
class FileStorage::UserData
	include JSON::Serializable

	property uid       : Int32
	# property token     : AuthD::User::Public?
	property uploads   : Array(FileStorage::Request::Upload)
	property downloads : Array(FileStorage::Request::Download)

	def initialize(@uid,
		@uploads   = Array(FileStorage::Request::Upload).new,
		@downloads = Array(FileStorage::Request::Download).new)
	end
end
