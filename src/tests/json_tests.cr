require "json"

require "../common/filestorage.cr"

unless ARGV.size > 0
	raise "Usage: json_tests file"
end

files_info = Array(FileStorage::FileInfo).new

ARGV.each do |filename|
	File.open(filename) do |file|
		files_info << FileStorage::FileInfo.new file, %w(important truc machin)
	end
end


token = FileStorage::Token.new 1002, "karchnu"

requests = Array(FileStorage::UploadRequest).new
files_info.each do |file_info|
	requests << FileStorage::UploadRequest.new file_info
end
authentication_message = FileStorage::Authentication.new token, requests

# TODO, TEST, DEBUG, XXX, FIXME
pp! authentication_message.to_json


am_from_json = FileStorage::Authentication.from_json authentication_message.to_json

pp! am_from_json
