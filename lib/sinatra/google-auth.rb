require 'omniauth-openid'

module Sinatra
  module GoogleAuth

    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        if env['rack.session']["user"] || env['REQUEST_PATH'] =~ /^\/auth\/google/
          @app.call(env)
        else
          env['rack.session']['google-auth-redirect'] = env['REQUEST_PATH']
          return [301, {'Content-Type' => 'text/html', 'Location' => '/auth/google'}, []]
        end
      end
    end

    module Helpers
      def authenticate
        unless session["user"]
          session['google-auth-redirect'] = request.path
          if settings.absolute_redirect?
            redirect "/auth/google"
          else
            redirect to "/auth/google"
          end
        end
      end

      def handle_authentication_callback
        puts 'handle_authentication_callback'
        unless session["user"]
          user_info = request.env["omniauth.auth"].info
          session["user"] = Array(user_info.email).first.downcase
          session["user_id"] = Array(user_info.id).first
          session["user_info"] = Array(user_info).to_s
          end
        end

        url = session['google-auth-redirect'] || to("/")
        redirect url
      end
    end

    def self.secret
      ENV['SESSION_SECRET'] || ENV['SECURE_KEY'] || 'please change me'
    end

    def self.registered(app)
      raise "Must supply ENV var GOOGLE_AUTH_URL" unless ENV['GOOGLE_AUTH_URL']
      app.helpers GoogleAuth::Helpers
      app.use ::Rack::Session::Cookie, :secret => secret
      app.use ::OmniAuth::Strategies::OpenID, :name => "google", :identifier => ENV['GOOGLE_AUTH_URL']
      app.set :absolute_redirect, false

      app.get "/auth/:provider/callback" do
        handle_authentication_callback
      end

      app.post "/auth/:provider/callback" do
        handle_authentication_callback
      end
    end
  end

  register GoogleAuth
end
