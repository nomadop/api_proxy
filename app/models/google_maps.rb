class GoogleMaps
	HOST = 'http://maps.googleapis.com'
	PROXY = ''

	def self.direction o_name, d_name, opts = {}
		conn = Conn.init(HOST) do |c|
			c.options[:proxy] = PROXY unless PROXY.blank?
			c.headers['Accept-Language'] = 'zh-CN,zh'
			c.params = {
				origin: o_name,
				destination: d_name,
				sensor: false,
				mode: 'transit'
			}.merge(opts)
			c.params[:departure_time] = Date.today.to_time.to_i + 10.hours if c.params[:mode] == 'transit'
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
				markers: ["size:small|","size:small|"],
				path: "color:0xff0000|weight:2|"
			}.merge(opts)
			c.params[:markers][0] += markers.first
			c.params[:markers][1] += markers.last
			c.params[:path] += "enc:#{path}"
		end
		response = conn.try(:get, '/maps/api/staticmap')
		case accept
		when :url
			response.headers['location']
		when :data
			response = conn.try(:get, response.headers['location']) if response.status == 301
			response.body
		end
	end

end