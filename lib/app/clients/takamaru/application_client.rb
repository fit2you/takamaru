module Takamaru
  class ApplicationClient
    include HTTParty

    default_timeout 120
    debug_output($stdout) if Rails.env.development?

    class << self
      private

      def do_request(method, path, options = {})
        response = send(method, path, options)
        return response if response.success?

        handle_errors(response, method, path)
      end

      def handle_errors(response, method, path)
        message = "#{name}##{caller[1][/`.*'/][1..-2]}: #{method.upcase} #{path}"

        case response.code
        when 404
          raise Takamaru::RecordNotFound, message
        else
          # FIXME: better handling errors
          raise Takamaru::Error, message
        end
      end

      def json_header
        { 'Content-Type' => 'application/json' }
      end

      def options
        { headers: json_header }
      end
    end
  end
end
