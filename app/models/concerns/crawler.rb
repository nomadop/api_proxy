class Crawler
	attr_reader :conn, :response, :doc, :cookie

	Host = ""

	def initialize
		@conn = Conn.init(self.class.const_get('Host'))
		@cookie = Cookie.new
	end

	def get url, params = {}
		@conn.headers[:cookie] = @cookie.to_s
		@conn.try(:get, url, params)
	end

	def goto url
		@response = get(url)
		@doc = Nokogiri::HTML(@response.body)
		@cookie.set_cookies(@response.headers['set-cookie'])
	end
end