require "ipc"
require "json"

require "./common.cr"

client = IPC::Client.new("pong")

token = Token.new 1002, "karchnu"
authentication_message = AuthenticationMessage.new token

client.send(1.to_u8, authentication_message.to_json)

m = client.read
# puts "message received: #{m.to_s}"
# puts "message received payload: #{String.new m.payload}"

response = Response.from_json(String.new m.payload)

if response.mid == authentication_message.mid
	puts "This is a response for the authentication message"
else
	puts "Message IDs from authentication message and its response differ"
end

client.close

#client.loop do |event|
#	case event
#	when IPC::Event::Message
#		puts "\033[32mthere is a message\033[00m"
#		puts event.message.to_s
#		client.close
#		exit
#	end
#end
