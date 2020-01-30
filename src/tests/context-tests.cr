require "../common/filestorage.cr"
require "ipc"
require "option_parser"

require "../server/context.cr"

filename = "./README.md"

tags = "readme example"

OptionParser.parse do |parser|
	parser.on "-f file-to-transfer",
		"--file to-transfer",
		"File to transfer (simulation)." do |opt|
		filename = opt
	end

	parser.on "-d database-directory",
		"--db-dir directory",
		"DB directory" do |opt|
		Context.file_info_directory = opt
		Context.db_reconnect
	end

	parser.on "-t tags",
		"--tags tags",
		"Tags, example: 'fruit bio comestible'" do |opt|
		tags = opt
	end

	parser.unknown_args do |args|
		pp! args
	end
end

pp! Context

fileinfo : FileStorage::FileInfo? = nil

File.open(filename) do |file|
	fileinfo = FileStorage::FileInfo.new file, tags.split(' ')
end

pp! fileinfo

transfer_info = TransferInfo.new 1000, fileinfo.not_nil!

Context.db << transfer_info

Context.db.each do |ti|
	pp! ti
end

