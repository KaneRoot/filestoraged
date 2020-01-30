require "../common/filestorage.cr"
require "ipc"
require "option_parser"

require "../common/utils.cr"
require "../server/context.cr"

filename = "./README.md"

tags = "readme example"

chunk_number_to_remove = 1

OptionParser.parse do |parser|
	parser.on "-f file-to-transfer",
		"--file to-transfer",
		"File to transfer (simulation)." do |opt|
		filename = opt
	end

	parser.on "-c chunk_number_to_remove",
		"--chunk-number chunk_number_to_remove",
		"Once the upload stard, we remove chunks. This test the removal of one of them in the DB." do |opt|
		chunk_number_to_remove = opt.to_i
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
		pp! args if args.size > 0
	end
end

fileinfo : FileStorage::FileInfo? = nil

File.open(filename) do |file|
	fileinfo = FileStorage::FileInfo.new file, tags.split(' ')
end

transfer_info = TransferInfo.new 1000, fileinfo.not_nil!

puts "transfer info of the file #{filename}"
puts
pp! transfer_info

puts
puts "store file info then remove a chunk (number #{chunk_number_to_remove})"
puts

Context.db << transfer_info

# remove the chunk once the information is recorded in the db
remove_chunk_from_db transfer_info, chunk_number_to_remove

Context.db.each do |ti|
	pp! ti
end

