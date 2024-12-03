require "json"
require "faraday"
require 'faraday/net_http_persistent'
require "time"
require "norairrecord/version"
require "norairrecord/client"
require "norairrecord/table"

module Norairrecord
  extend self
  attr_accessor :api_key, :throttle, :base_url, :user_agent

  Error = Class.new(StandardError)

  def throttle?
    return true if @throttle.nil?

    @throttle
  end
end
