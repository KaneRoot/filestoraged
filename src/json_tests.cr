require "json"

require "./common.cr"

files_info = Array(FileInfo).new
files_info << FileInfo.new "file.txt", 4123.to_u64, %w(important truc machin)

token = Token.new 1002, "karchnu"
authentication_message = AuthenticationMessage.new token, files_info

# TODO, TEST, DEBUG, XXX, FIXME
pp! authentication_message.to_json


am_from_json = AuthenticationMessage.from_json authentication_message.to_json

pp! am_from_json
