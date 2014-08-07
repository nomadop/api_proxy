class GoogleMaps
	HOST = 'http://maps.googleapis.com'
	PROXY = 'http://127.0.0.1:8087'

	def self.direction o_name, d_name, opts = {}
		conn = Conn.init(HOST) do |c|
			c.options[:proxy] = PROXY unless PROXY.blank?
			c.headers['Accept-Language'] = 'zh-CN,zh'
			c.params = {
				origin: o_name,
				destination: d_name,
				sensor: false,
				mode: 'transit',
				departure_time: Time.now.to_i
			}.merge(opts)
		end
		response = conn.try(:get, '/maps/api/directions/json')
		if response.status == 301
			response = conn.try(:get, response.headers['location'])
		end
		JSONObject.new(response.body)
	end

	def self.staticmap markers, path, accept = :url, opts = {}
		conn = Conn.init(HOST) do |c|
			c.options[:proxy] = PROXY unless PROXY.blank?
			c.headers['Accept-Language'] = 'zh-CN,zh'
			c.params = {
				size: '500x500',
				scale: 2,
				markers: "size:small|",
				path: "color:0xff0000|weight:2|"
			}.merge(opts)
			c.params[:markers] += markers.join('|')
			c.params[:path] += "enc:#{path}"
		end
		response = conn.try(:get, '/maps/api/staticmap')
		case accept
		when :url
			response.headers['location']
		when :data
			response = conn.try(:get, response.headers['location'])
			response.body
		end
	end

end