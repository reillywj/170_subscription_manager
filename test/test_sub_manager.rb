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

  def method_missing(method_sym, *arguments, &block)
    regex_to_match = /^response_(\d{3})\?/
    if method_sym.to_s =~ regex_to_match
      number = method_sym.to_s.match(regex_to_match).to_a.last.to_i
      assert_equal number, last_response.status
    else
      super
    end
  end

  def add_subscription(name = 'hbr',
                       url = 'www.hbr.com',
                       frequency = '1',
                       amount = '100.00')
    post '/add', 'name' => name,
                 'url' => url,
                 'frequency' => frequency,
                 'cost' => amount
  end

  # -------------------Tests-------------

  def test_index
    add_subscription 'Harvard Business Review'
    follow_redirect!

    get '/'
    response_200?
    body_includes 'Add Subscription', 'Harvard Business Review', '/harvard-business-review', 'Total'
  end

  def test_new
    get '/add'
    response_200?
    body_includes 'Add New Subscription', '</form>',
                  '<button type="submit">Add</button>',
                  'frequency', 'cost', 'url'

    add_subscription
    response_302?

    follow_redirect!
    expected_message = 'hbr has been added to your subscriptions.'
    body_includes 'hbr', expected_message

    get '/'
    refute_includes last_response.body, expected_message
  end

  def test_view_subscription
    add_subscription
    follow_redirect!

    get '/hbr'
    response_200?
    body_includes 'hbr', 'www.hbr.com', '$100.00/year', '/hbr/edit', 'Edit'
  end

  def test_invalid_subscription
    get '/hbr'
    response_302?

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

  def test_edit
    add_subscription
    follow_redirect!

    get '/hbr/edit'
    response_200?
    body_includes 'hbr', 'hbr', 'www.hbr.com', '100.00', '/hbr/edit', '<form'
  end

  def test_update_subscription
    add_subscription
    follow_redirect!

    post '/hbr/edit',
         'name' => 'Harvard Business Review',
         'url' => 'www.hbr.com',
         'frequency' => '1',
         'cost' => '250.2'
    response_302?
    follow_redirect!

    response_200?
    body_includes 'Harvard Business Review',
                  'www.hbr.com',
                  '$250.20/year', 'Harvard Business Review has been updated.'
  end
end






















