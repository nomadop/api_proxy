module GoogleApis
	module Wraper
		HOST = 'https://www.googleapis.com'
		KEYS = ['AIzaSyAXngIRBBzOVy_k9OIjEn9rW33FPCEJ6C0']
		@@current = 0

		def self.key
			@@current += 1
			@@current = 0 if @@current >= KEYS.size
			KEYS[@@current]
		end

		def self.translate params = {}
			conn = Conn.init(HOST)
			conn.params = params.merge({key: key})
			response = conn.try(:get, "/language/translate/v2")
			while response.status == 301
				response = conn.try(:get, response.headers['location'])
			end
			JSONObject.new(response.body)
		end
	end

	module Crawler
		HOST = 'https://www.google.com/'

		def self.translate params = {}
			conn = Conn.init('https://translate.google.com')
			conn.params = params
			response = conn.try(:get, "/translate_a/single")
			while response.status == 301
				response = conn.try(:get, response.headers['location'])
			end
			JSONObject.new(response.body)
		end
	end
end