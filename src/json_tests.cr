require "json"

require "./common.cr"


token = Token.new 1002, "karchnu"
authentication_message = AuthenticationMessage.new token

# TODO, TEST, DEBUG, XXX, FIXME
pp! authentication_message.to_json

am_from_json = AuthenticationMessage.from_json authentication_message.to_json

pp! am_from_json
