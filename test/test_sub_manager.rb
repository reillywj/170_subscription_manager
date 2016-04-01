ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'
require_relative '../sub_manager'

class SubManagerTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    subscription = {'hbr' => {'website' => 'www.hbr.com', 'frequency' => 1, 'amount'=> 10000}}
    FileUtils.touch('test/subscriptions.yml')
    File.open('test/subscriptions.yml', 'w') { |f| f.write subscription.to_yaml}
  end

  def teardown
    FileUtils.rm('test/subscriptions.yml')
  end

  def body_includes(value)
    assert_includes last_response.body, value
  end

  def test_index
    get '/'
    assert_equal 200, last_response.status
    body_includes 'Add'
  end

  def test_new
    get '/add'
    assert_equal 200, last_response.status
    body_includes 'Add New Subscription'
    body_includes '</form>'
    body_includes '<button type="submit">Add</button>'

    post '/add', {'name' => 'Ruby Weekly'}
    assert_equal 302, last_response.status

    follow_redirect!
    body_includes 'Ruby Weekly'
    expected_message = 'Ruby Weekly has been added to your subscriptions.'
    body_includes expected_message

    get '/'
    refute_includes last_response.body, expected_message
  end
end