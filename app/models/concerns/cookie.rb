class Cookie
	def initialize
		@cookies = []
	end

	def set_cookies str
		return if str.blank?
		cookies = str.split(', ')
		cookies = 0.step(cookies.size - 1, 2).map do |i|
			cookies[i] + ', ' + cookies[i + 1]
		end
		cookies.each{|s| set_cookie(s)}
		to_s
	end

	def set_cookie str
		kvps = str.split('; ')
		name, value = kvps[0].split('=', 2)
		cookie = { name: name, value: value	}
		kvps[1..-1].each do |kvp|
			k, v = kvp.split('=')
			cookie[k.to_sym] = v
		end
		old_cookies = @cookies.find{|c| c[:name] == name}
		if old_cookies
			old_cookies.merge(cookie)
		else
			@cookies << cookie
		end
	end

	def to_s
		@cookies.map{|c| "#{c[:name]}=#{c[:value]}"}.join('; ')
	end
end