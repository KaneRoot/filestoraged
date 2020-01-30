
def remove_chunk_from_db(transfer_info : TransferInfo, chunk_number : Int32)
	transfer_info.chunks.delete chunk_number
	Context.db_by_filedigest.update transfer_info.file_info.digest, transfer_info
end

def write_a_chunk(userid : String, file_info : FileStorage::FileInfo, chunk_number : Int32, data : Bytes)

	# storage: Context.storage_directory/userid/fileuuid.bin
	dir = "#{Context.storage_directory}/#{userid}"

	FileUtils.mkdir_p dir

	path = "#{dir}/#{file_info.digest}.bin"
	# Create file if non existant
	File.open(path, "a+") do |file|
	end

	# Write in it
	File.open(path, "ab") do |file|
		offset = chunk_number * FileStorage.message_buffer_size
		file.seek(offset, IO::Seek::Set)
		file.write data
	end
end

###	# TODO:
###	#   why getting the file_info here? We could check for the transfer_info right away
###	#   it has more info, and we'll get it later eventually
###
###	file_info = nil
###	begin
###		file_info = user.uploads.select do |v|
###			v.file.digest == message.filedigest
###		end.first.file
###
###		pp! file_info
###	rescue e : IndexError
###		puts "No recorded upload request for file #{message.filedigest}"
###
###	rescue e
###		puts "Unexpected error: #{e}"
###	end
