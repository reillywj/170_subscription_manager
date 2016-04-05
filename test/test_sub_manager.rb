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
    FileUtils.touch('test/subscriptions.yml')
  end

  def teardown
    FileUtils.rm('test/subscriptions.yml')
  end

  def body_includes(value)
    assert_includes last_response.body, value
  end

  def add_subscription(name='hbr', url='www.hbr.com', frequency='1', amount='100.00')

    post '/add', {'name' => name, 'url' => url, 'frequency'=>frequency, 'cost' => amount}
  end


  # -------------------Tests-------------

  def test_index
    add_subscription

    get '/'
    assert_equal 200, last_response.status
    body_includes 'Add'
    body_includes 'hbr'
  end

  def test_new
    get '/add'
    assert_equal 200, last_response.status
    body_includes 'Add New Subscription'
    body_includes '</form>'
    body_includes '<button type="submit">Add</button>'
    body_includes 'frequency'
    body_includes 'cost'
    body_includes 'url'

    add_subscription
    assert_equal 302, last_response.status

    follow_redirect!
    body_includes 'hbr'
    expected_message = 'hbr has been added to your subscriptions.'
    body_includes expected_message

    get '/'
    refute_includes last_response.body, expected_message
  end

  def test_view_subscription
    add_subscription
    follow_redirect!

    get '/hbr'
    assert_equal 200, last_response.status
    body_includes 'hbr'
    body_includes 'www.hbr.com'
    body_includes '$100.00/year'
  end

  def test_invalid_subscription
    get '/hbr'
    assert_equal 302, last_response.status

    follow_redirect!
    assert_equal 200, last_response.status
    body_includes 'Invalid Request.'
  end
end