# frozen_string_literal: true

require 'net/http'
require 'json'
require 'digest/md5'
require 'uri'

module RedmineMailchimp
  # Minimal client for the Mailchimp Marketing API v3.
  # The plugin used to rely on the "mailchimp-api" gem, which only supports the retired API 2.0.
  class Client
    API_KEY_FORMAT = /\A[0-9a-zA-Z]+-(?<datacenter>[a-z]+\d+)\z/
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10
    PAGE_SIZE = 1000
    MEMBER_EXISTS = 'Member Exists'

    NETWORK_ERRORS = [
      SocketError, IOError, SystemCallError, Timeout::Error,
      OpenSSL::SSL::SSLError, Net::ProtocolError
    ].freeze

    def initialize(api_key)
      key = api_key.to_s.strip
      match = API_KEY_FORMAT.match(key)
      raise Error, 'Invalid Mailchimp API key: expected a key ending with a datacenter such as "-us1"' unless match

      @api_key = key
      @host = "#{match[:datacenter]}.api.mailchimp.com"
    end

    # Returns [{ 'id' => ..., 'name' => ... }, ...]
    def lists
      get('lists', count: PAGE_SIZE, fields: 'lists.id,lists.name').fetch('lists', [])
    end

    # Returns the merge field tags of a list, e.g. ["EMAIL", "FNAME", "LNAME", "PHONE"]
    def merge_field_tags(list_id)
      response = get("lists/#{escape(list_id)}/merge-fields", count: PAGE_SIZE, fields: 'merge_fields.tag')
      response.fetch('merge_fields', []).map { |field| field['tag'] }
    end

    # Adds the address to the list. With update_existing, members that already exist are updated;
    # otherwise they are left untouched. status_if_new only applies to new members, so existing
    # unsubscribed members are never resubscribed.
    def subscribe(list_id, email, merge_fields: {}, double_optin: true, update_existing: true)
      status = double_optin ? 'pending' : 'subscribed'
      fields = merge_fields.transform_values(&:to_s)

      if update_existing
        put("lists/#{escape(list_id)}/members/#{subscriber_hash(email)}",
            email_address: email, status_if_new: status, merge_fields: fields)
      else
        post("lists/#{escape(list_id)}/members",
             email_address: email, status: status, merge_fields: fields)
      end
      true
    rescue Error => e
      raise unless !update_existing && e.title == MEMBER_EXISTS

      true
    end

    private

    def subscriber_hash(email)
      Digest::MD5.hexdigest(email.to_s.strip.downcase)
    end

    def escape(value)
      ERB::Util.url_encode(value.to_s)
    end

    def get(path, query = {})
      request(Net::HTTP::Get, path, query: query)
    end

    def put(path, body)
      request(Net::HTTP::Put, path, body: body)
    end

    def post(path, body)
      request(Net::HTTP::Post, path, body: body)
    end

    def request(klass, path, query: nil, body: nil)
      uri = URI::HTTPS.build(host: @host, path: "/3.0/#{path}", query: query && URI.encode_www_form(query))
      req = klass.new(uri)
      req.basic_auth('redmine', @api_key)
      req['Accept'] = 'application/json'
      if body
        req['Content-Type'] = 'application/json'
        req.body = body.to_json
      end

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      parse(http.request(req))
    rescue *NETWORK_ERRORS => e
      raise Error, "Mailchimp request failed: #{e.class}: #{e.message}"
    end

    def parse(response)
      data = response.body.to_s.empty? ? {} : JSON.parse(response.body)
      return data if response.is_a?(Net::HTTPSuccess)

      title = data['title'] if data.is_a?(Hash)
      detail = data['detail'] if data.is_a?(Hash)
      raise Error.new("Mailchimp API error #{response.code}: #{[title, detail].compact.join(' - ')}",
                      status: response.code.to_i, title: title)
    rescue JSON::ParserError
      raise Error.new("Mailchimp API returned an invalid response (HTTP #{response.code})",
                      status: response.code.to_i)
    end
  end
end
