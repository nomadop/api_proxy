class GoogleMaps
	HOST = 'http://maps.googleapis.com'
	PROXY = ''

	def self.direction o_name, d_name, optional = {}
		conn = Conn.init(HOST) do |c|
			c.options[:proxy] = PROXY unless PROXY.blank?
			c.headers['Accept-Language'] = 'zh-CN,zh'
			c.params = {
				origin: o_name,
				destination: d_name,
				sensor: false,
				mode: 'transit',
				departure_time: Time.now.to_i
			}.merge(optional)
		end
		response = conn.try(:get, '/maps/api/directions/json')
		if response.status == 301
			response = conn.try(:get, response.headers['location'])
		end
		JSONObject.new(response.body)
	end

	def self.staticmap o_pos, d_pos, path, optional = {}
		conn = Conn.init(HOST) do |c|
			c.options[:proxy] = PROXY unless PROXY.blank?
			c.headers['Accept-Language'] = 'zh-CN,zh'
			c.params = {
				size: '500x500',
				scale: 2,
				markers: "size:small",
				path: "color:0x0000ff|weight:2"
			}.merge(optional)
			c.params[:markers] += "|#{o_pos}|#{d_pos}"
			c.params[:path] += "|enc:#{path}"
		end
		response = conn.try(:get, '/maps/api/staticmap')
		response.headers['location']
	end

end