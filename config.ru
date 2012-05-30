require "bundler"
Bundler.setup
Bundler.require

module Rack
  class CorsPrefetch
    def cors_headers(env)
      
      host    = env['HTTP_ORIGIN']
      if env['Access-Control-Request-Headers']
        headers = env['Access-Control-Request-Headers']
      else
        headers = env.keys.select{ |k| k =~ /^HTTP_/ }.map { |k| k.downcase.gsub(/_/, '-').gsub(/^http-/, '') }.join ', '
      end
      

      
      
      puts 'env'
      puts env.inspect
      
      headers = {
        'Access-Control-Allow-Methods'      => 'POST, GET, PUT, PATCH, DELETE',
        'Access-Control-Max-Age'            => '86400', # 24 hours
        # 'Access-Control-Allow-Headers'      => headers,
        'Access-Control-Allow-Headers'      => 'Accept, Accept-Charset, Accept-Encoding, Accept-Language, Authorization, Content-Length, Content-Type, Host, Origin, Proxy-Connection, Referer, User-Agent, X-Requested-With, X-Redmine-API-Key',
        'Access-Control-Allow-Credentials'  => 'true',
        'Access-Control-Allow-Origin'       => host
      }
      
      puts headers.inspect
      
      headers
    end
    FORCED_SSL_MSG = "CORS requests only allowed via https://"

    def initialize(app)
      @app = app
      # @force_ssl = true
    end

    def call(env)
      force_ssl(env) || process_preflight(env) || process_cors(env) || process_failed(env)
    end

    private
      def force_ssl(env)
        return if !@force_ssl || ssl_request?(env)
        log("NonSSL", env)
        [403, {'Content-Type' => 'text/plain'}, [FORCED_SSL_MSG]]
      end

      def process_preflight(env)
        return unless env['HTTP_ORIGIN'] && env['HTTP_ACCESS_CONTROL_REQUEST_METHOD'] && env['REQUEST_METHOD'] == 'OPTIONS'
        log("Preflight", env)
        [204, cors_headers(env), []]
      end

      def process_cors(env)
        log("Cors", env)
        status, headers, body = @app.call(env)
        
        env['rack.errors'].write "status: #{status}\n"
        headers.each do |key, val|
          env['rack.errors'].write "#{key}: #{val}\n"
        end
        env['rack.errors'].write "\n#{body.inspect}\n\n"
        
        [status, headers.merge(cors_headers(env)), body]
      end

      def process_failed(env)
        log("Failed", env)
        [404, {'Content-Type' => 'text/plain'}, []]
      end

      # Fixed in rack >= 1.3
      def ssl_request?(env)
        if env['HTTPS'] == 'on'
          'https'
        elsif env['HTTP_X_FORWARDED_PROTO']
          env['HTTP_X_FORWARDED_PROTO'].split(',')[0]
        else
          env['rack.url_scheme']
        end == 'https'
      end

      def log(kind, env)
        logger = @logger || env['rack.errors']
        logger.write(
          "#{kind} request #{env['REQUEST_PATH']} \n" +
          "origin: #{env['HTTP_ORIGIN']} \n" +
          "referer: #{env['HTTP_REFERER']} \n" +
          "authorization: #{env["HTTP_AUTHORIZATION"]} \n" +
          "method: #{env['REQUEST_METHOD']} \n\n"
        )
      end
  end
end

use Rack::CorsPrefetch
use Rack::StreamingProxy do |request|
  # inside the request block, return the full URI to redirect the request to,
  # or nil/false if the request should continue on down the middleware stack.
  
  protocol, host, path = request.url.scan(/^(https?):\/\/[^\/]+\/([^\/]+)(.*)/).flatten

  puts "redirecting to #{protocol}://#{host}#{path}"
  
  "#{protocol}://#{host}#{path}"
end
run proc{|env| [200, {"Content-Type" => "text/plain"}, ""] }