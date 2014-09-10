module GoogleApis
	KEYS = ['AIzaSyAfy5gDr5-vhv0_ZF_BOQHA4_Fx-6sGJAU',
					'AIzaSyBPLzOXa6a-fLACftN7qLXvxzCyduKGb0M',
					'AIzaSyBgw09mhfPKR1Ded7RIAn7zveSCum2bf20',
					'AIzaSyDvg0BiuEgxxZuf20Bhujw6jYO0BzLYsO0',
					'AIzaSyA7swEwrzDr0SYSqA1lLtuo9RI6CbCIwtA']
	@@current = 0

	def self.key
		@@current += 1
		@@current = 0 if @@current >= KEYS.size
		KEYS[@@current]
	end

	module Wraper
		HOST = 'https://www.googleapis.com'

		def self.translate params = {}
			conn = Conn.init(HOST)
			conn.params = params.merge({key: GoogleApis.key})
			response = conn.try(:get, "/language/translate/v2")
			while response.status == 301
				response = conn.try(:get, response.headers['location'])
			end
			JSONObject.new(response.body)
		end
	end

	module Crawler
		def self.translate params = {}
			conn = Conn.init('https://translate.google.com')
			conn.params = {
				sl: params[:source] || params[:sl],
				tl: params[:target] || params[:tl],
				text: params[:q],
				client: 't' 
			}
			response = conn.try(:get, "/translate_a/t")
			while response.status == 301
				response = conn.try(:get, response.headers['location'])
			end
			JSON.parse(response.body.gsub(/,+/, ','))[0][0][0]
		end
	end
end