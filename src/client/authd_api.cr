
def authd_get_token(key_file : String? = nil, login : String? = nil, pass : String? = nil)

	authd = AuthD::Client.new
	key_file.try do |file| # FIXME: fail if missing?
		authd.key = File.read(file).chomp
	end

	token = authd.get_token? login, pass
	raise "cannot get a token" if token.nil?
	authd.close

	token
end
