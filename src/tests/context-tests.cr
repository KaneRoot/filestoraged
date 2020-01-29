require "../common/filestorage.cr"
require "ipc"
require "option_parser"

filename = "./README.md"

OptionParser.parse do |parser|
	parser.on "-f file-to-transfer",
		"--file to-transfer",
		"File to transfer (simulation)." do |opt|
		filename = opt
	end

	parser.unknown_args do |args|
		pp! args
	end
end

require "../server/context.cr"

pp! Context
