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

  def body_includes(*values)
    values.each do |value|
      assert_includes last_response.body, value
    end
  end

  def response_200?
    assert_equal 200, last_response.status
  end

  def add_subscription(name='hbr', url='www.hbr.com', frequency='1', amount='100.00')

    post '/add', {'name' => name, 'url' => url, 'frequency'=>frequency, 'cost' => amount}
  end


  # -------------------Tests-------------

  def test_index
    add_subscription

    get '/'
    response_200?
    body_includes 'Add', 'hbr'
  end

  def test_new
    get '/add'
    response_200?
    body_includes 'Add New Subscription',
                  '</form>',
                  '<button type="submit">Add</button>',
                  'frequency',
                  'cost',
                  'url'

    add_subscription
    assert_equal 302, last_response.status

    follow_redirect!
    expected_message = 'hbr has been added to your subscriptions.'
    body_includes 'hbr',
                  expected_message

    get '/'
    refute_includes last_response.body, expected_message
  end

  def test_view_subscription
    add_subscription
    follow_redirect!

    get '/hbr'
    response_200?
    body_includes 'hbr',
                  'www.hbr.com',
                  '$100.00/year',
                  '/hbr/edit',
                  'Edit'
  end

  def test_invalid_subscription
    get '/hbr'
    assert_equal 302, last_response.status

    follow_redirect!
    response_200?
    body_includes 'Invalid Request.'
  end

  def test_sluggified_subscription
    add_subscription('Slugify Me!', 'www.slugify-me.com', '12', '10.99')
    follow_redirect!

    get '/slugify-me'
    response_200?
    body_includes 'Slugify Me!', 'www.slugify-me.com', '$10.99/month'
  end
end






















