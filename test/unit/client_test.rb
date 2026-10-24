# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class RedmineMailchimp::ClientTest < ActiveSupport::TestCase
  API_KEY = MAILCHIMP_TEST_API_KEY

  class FakeHttp
    attr_reader :requests
    attr_accessor :use_ssl, :open_timeout, :read_timeout

    def initialize(*responses)
      @responses = responses
      @requests = []
    end

    def request(req)
      @requests << req
      @responses.shift
    end
  end

  def ok(body = {})
    resp = Net::HTTPOK.new('1.1', '200', 'OK')
    resp.stubs(:body).returns(body.to_json)
    resp
  end

  def error_response(klass, code, title, detail = nil)
    resp = klass.new('1.1', code.to_s, 'err')
    resp.stubs(:body).returns({ 'title' => title, 'detail' => detail, 'status' => code }.to_json)
    resp
  end

  def stub_http(*responses)
    http = FakeHttp.new(*responses)
    Net::HTTP.stubs(:new).returns(http)
    http
  end

  def client
    RedmineMailchimp::Client.new(API_KEY)
  end

  test 'rejects an API key without datacenter' do
    assert_raise(RedmineMailchimp::Error) { RedmineMailchimp::Client.new('abc123') }
    assert_raise(RedmineMailchimp::Error) { RedmineMailchimp::Client.new('') }
    assert_raise(RedmineMailchimp::Error) { RedmineMailchimp::Client.new(nil) }
  end

  test 'lists uses the datacenter host, basic auth and returns id/name' do
    http = FakeHttp.new(ok('lists' => [{ 'id' => 'abc', 'name' => 'Members' }]))
    Net::HTTP.expects(:new).with('us12.api.mailchimp.com', 443).returns(http)

    assert_equal [{ 'id' => 'abc', 'name' => 'Members' }], client.lists

    assert http.use_ssl
    assert_equal RedmineMailchimp::Client::READ_TIMEOUT, http.read_timeout
    req = http.requests.first
    assert_equal '/3.0/lists', req.path.split('?').first
    assert_includes req.path, 'count=1000'
    assert_equal "Basic #{["redmine:#{API_KEY}"].pack('m0')}", req['Authorization']
  end

  test 'merge_field_tags returns tags' do
    http = stub_http(ok('merge_fields' => [{ 'tag' => 'EMAIL' }, { 'tag' => 'PHONE' }]))

    assert_equal %w[EMAIL PHONE], client.merge_field_tags('list 1')
    assert_match %r{\A/3\.0/lists/list%201/merge-fields\?}, http.requests.first.path
  end

  test 'subscribe upserts with a lowercase md5 subscriber hash and pending status for double opt-in' do
    http = stub_http(ok)

    assert client.subscribe('list1', 'John@Example.COM', merge_fields: { 'FNAME' => 'John', 'AGE' => nil },
                            double_optin: true, update_existing: true)

    req = http.requests.first
    assert_kind_of Net::HTTP::Put, req
    assert_equal "/3.0/lists/list1/members/#{Digest::MD5.hexdigest('john@example.com')}", req.path
    assert_equal({ 'email_address' => 'John@Example.COM', 'status_if_new' => 'pending',
                   'merge_fields' => { 'FNAME' => 'John', 'AGE' => '' } }, JSON.parse(req.body))
  end

  test 'subscribe uses subscribed status without double opt-in' do
    http = stub_http(ok)
    client.subscribe('list1', 'a@example.com', double_optin: false)
    assert_equal 'subscribed', JSON.parse(http.requests.first.body)['status_if_new']
  end

  test 'subscribe without update_existing posts and ignores existing members' do
    http = stub_http(error_response(Net::HTTPBadRequest, 400, 'Member Exists', 'already a list member'))

    assert client.subscribe('list1', 'a@example.com', update_existing: false)
    req = http.requests.first
    assert_kind_of Net::HTTP::Post, req
    assert_equal '/3.0/lists/list1/members', req.path
    assert_equal 'pending', JSON.parse(req.body)['status']
  end

  test 'subscribe raises other API errors' do
    stub_http(error_response(Net::HTTPBadRequest, 400, 'Invalid Resource', 'looks fake'))

    e = assert_raise(RedmineMailchimp::Error) { client.subscribe('list1', 'a@example.com') }
    assert_equal 400, e.status
    assert_equal 'Invalid Resource', e.title
    assert_match(/looks fake/, e.message)
  end

  test 'member exists is only ignored when update_existing is off' do
    stub_http(error_response(Net::HTTPBadRequest, 400, 'Member Exists'))
    assert_raise(RedmineMailchimp::Error) { client.subscribe('list1', 'a@example.com', update_existing: true) }
  end

  test 'network errors are wrapped' do
    Net::HTTP.stubs(:new).returns(http = FakeHttp.new)
    http.stubs(:request).raises(Net::OpenTimeout)
    e = assert_raise(RedmineMailchimp::Error) { client.lists }
    assert_match(/Net::OpenTimeout/, e.message)
  end

  test 'non JSON responses are reported' do
    resp = Net::HTTPBadGateway.new('1.1', '502', 'Bad Gateway')
    resp.stubs(:body).returns('<html>oops</html>')
    stub_http(resp)

    e = assert_raise(RedmineMailchimp::Error) { client.lists }
    assert_match(/502/, e.message)
  end
end
