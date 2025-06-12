require_relative 'faraday_rate_limiter'
require 'erb'

module Norairrecord
  class Client
    attr_reader :api_key
    attr_writer :connection

    # Per Airtable's documentation you will get throttled for 30 seconds if you
    # issue more than 5 requests per second. Airrecord is a good citizen.
    AIRTABLE_RPS_LIMIT = 5

    def initialize(api_key)
      @api_key = api_key
    end

    def connection
      @connection ||= Faraday.new(
        url: Norairrecord.base_url || ENV['AIRTABLE_ENDPOINT_URL'] || "https://api.airtable.com",
        headers: {
          "Authorization" => "Bearer #{api_key}",
          "User-Agent"    => Norairrecord.user_agent || "Airrecord (nora's version)/#{Norairrecord::VERSION}",
        },
      ) do |conn|
        if Norairrecord.throttle?
          conn.request :airrecord_rate_limiter, requests_per_second: Norairrecord.rps_limit || AIRTABLE_RPS_LIMIT
        end
        conn.adapter :net_http_persistent
      end
    end

    def escape(*args) 
      ERB::Util.url_encode(*args)
    end

    def parse(body)
      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    def handle_error(status, error)
      raise RecordNotFoundError if status == 404
      if error.is_a?(Hash) && error['error']
        raise Error, "HTTP #{status}: #{error['error']['type']}: #{error['error']['message']}"
      else
        raise Error, "HTTP #{status}: Communication error: #{error}"
      end
    end
  end
end
