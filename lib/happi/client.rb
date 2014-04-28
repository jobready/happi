require 'faraday'
require 'faraday_middleware'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/hash'

class Happi::Client
  DEFAULTS = {
    host: 'http://localhost:8080',
    port: 443,
    timeout: 60,
    version: 'v1'
  }

  attr_accessor :oauth_token, :host, :port, :timeout, :version

  def initialize(options = {})
    DEFAULTS.merge(options).each do |key, value|
      send("#{key}=", value)
    end

    if block_given?
      yield
    end
  end

  def get(resource, params = {})
    call(:get, url(resource), param_check(params))
        .body.with_indifferent_access
  end

  def patch(resource, params = {})
    call(:patch, url(resource), param_check(params))
        .body.with_indifferent_access
  end

  def post(resource, params = {})
    call(:post, url(resource), param_check(params))
        .body.with_indifferent_access
  end

  def url(resource)
    "/api/#{version}/#{resource}"
  end

  def call(method, url, params)
    logger.info("#{method}, #{url}, #{params}")
    response = connection.send(method, url, params)
    raise_error(response) if errors[response.status]
    response
  end

  def raise_error(response)
    if response.body['errors']
      message = response.body['errors']
    else
      message = response.body
    end

    fail errors[response.status].new(message)
  end

  def logger
    @logger ||= Logger.new(STDOUT)
  end

  def param_check(params)
    Hash[params.map do |key, value|
      if value.is_a? Hash
        [key, param_check(value)]
      end
      if value.respond_to?(:multipart)
        [key, value.multipart]
      else
        [key, value]
      end
    end]
  end

  def connection
    @connection ||= Faraday.new(host) do |f|
      f.request :multipart
      f.use FaradayMiddleware::OAuth2, oauth_token
      f.use FaradayMiddleware::ParseJson, content_type: 'application/json'
      f.request :url_encoded
      f.adapter :net_http
    end
  end

  def errors
    @errors ||= {
      400 => Happi::Error::BadRequest,
      401 => Happi::Error::Unauthorized,
      403 => Happi::Error::Forbidden,
      404 => Happi::Error::NotFound,
      406 => Happi::Error::NotAcceptable,
      408 => Happi::Error::RequestTimeout,
      422 => Happi::Error::UnprocessableEntity,
      429 => Happi::Error::TooManyRequests,
      500 => Happi::Error::InternalServerError,
      502 => Happi::Error::BadGateway,
      503 => Happi::Error::ServiceUnavailable,
      504 => Happi::Error::GatewayTimeout,
    }
  end
end