
OptionParser.parse do |parser|
	parser.on "-d storage-directory",
		"--storage-directory storage-directory",
		"The directory where to put uploaded files." do |opt|
		Context.storage_directory = opt
	end

	parser.on "-s service-name", "--service-name service-name", "Service name." do |name|
		Context.service_name = name
	end

	parser.on "-h", "--help", "Show this help" do
		puts parser
		exit 0
	end
end
