require "../common/filestorage.cr"

# This file test the following code
# classes:
#   * Chunk, FileInfo
#   * UploadRequest, DownloadRequest
#   * AuthenticationMessage, Response, TransferMessage
# functions:
#   * data_digest, file_digest

# data_digest
# `echo -n "coucou" | sha256sum`
# => 110812f67fa1e1f0117f6f3d70241c1a42a7b07711a93c2477cc516d9042f9db

filename = "./README.md"

data = "coucou".chomp.to_slice
pp! FileStorage.data_digest data

puts

# file_digest
# `cat README.md | sha256sum`
# => 79c66991a965185958a1efb17d12652bdd8dc2de0da89b2dc152e2eeb2e02eff
File.open(filename) do |file|
	pp! FileStorage.file_digest file
end

puts

# Chunk
pp! FileStorage::Chunk.new 1, 2, "blablabla"

puts

# FileInfo
File.open(filename) do |file|
	pp! FileStorage::FileInfo.new file, [ "tag1", "tag2" ]
end

puts

# Token
# XXX: should not exist, it will be replaced by an authd JWT token soon.
token = FileStorage::Token.new 1002, "jean-dupont"
pp! token

puts

# for later
requests = Array(FileStorage::Message::Request).new

# UploadRequest
File.open(filename) do |file|
	file_info = FileStorage::FileInfo.new file, [ "tag1", "tag2" ]
	upload_request = FileStorage::Message::UploadRequest.new file_info
	pp! upload_request
	requests << upload_request
end

puts

# DownloadRequest
pp! FileStorage::Message::DownloadRequest.new uuid: "abc"
pp! FileStorage::Message::DownloadRequest.new name: "the other one"
pp! FileStorage::Message::DownloadRequest.new tags: [ "tag1", "tag2" ]

puts

# AuthenticationMessage
pp! FileStorage::Message::Authentication.new token, requests

puts

# Response
pp! FileStorage::Message::Response.new "UUID", "Ok"
pp! FileStorage::Message::Response.new "UUID", "Error", "Cannot store the file"

puts

# TransferMessage
File.open(filename) do |file|
	file_info = FileStorage::FileInfo.new file, [ "tag1", "tag2" ]

	somedata = "coucou".to_slice
	pp! FileStorage::Message::Transfer.new file_info, 1, somedata
end
