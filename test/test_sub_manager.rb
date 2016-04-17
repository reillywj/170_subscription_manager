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
    # FileUtils.touch('test/subscriptions.yml')
    FileUtils.touch('test/users.yml')
  end

  def teardown
    # FileUtils.rm('test/subscriptions.yml')
    FileUtils.rm('test/users.yml')
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

  def add_subscription(username = 'default', name = 'hbr', url = 'www.hbr.com', frequency = '1', amount = '100.00')
    users = users_to_manage
    users[username]['subscriptions'][sluggify(name)] = { 'name' => name, 'cost' => to_cents(amount), 'frequency' => frequency.to_i, 'url' => url } if users[username]
    update_users users
  end

  def try_signup(username='default', password='password')
    post '/signup', 'username' => username, 'password' => password
  end

  def invalid_signup(username, password)
    try_signup username, password
    response_401?
  end

  def login_user(username='default', password='password')
    post '/login', 'username' => username, 'password' => password
  end

  def sign_up_and_log_in
    try_signup
    login_user
    follow_redirect!
  end

  def not_logged_in_test(fullpath='/', message=nil)
    get fullpath
    response_200?
    body_includes 'Sign Up', 'Username:', 'Password:', 'Already have an account? <a', 'Login Here!', message.to_s
  end

  def must_be_logged_in(fullpath, message="You must be logged in!")
    not_logged_in_test(fullpath, message)
    sign_up_and_log_in
  end

  # -------------------Tests-------------

  def test_signup
    get '/signup'
    response_200?
    body_includes 'Username', 'Password', 'Signup', '<input'

    try_signup
    response_302?
    follow_redirect!

    body_includes 'Welcome, default!', "default's Subscriptions"

  end

  def test_invalid_signup
    valid_username = 'username1234'
    valid_password = 'password1234'
    invalid_signup valid_username, '' # no password
    invalid_signup valid_username, 'toolongofapasswordtobeapasswordforthisapp'
    invalid_signup '', valid_password # no username
    invalid_signup 'username with spaces', valid_password
    invalid_signup 'usernamewith%#$', valid_password
    body_includes 'Invalid inputs.'
  end

  def test_invalid_signup_duplicate_user
    try_signup 'test_username', 'password'
    follow_redirect!
    try_signup 'test_username', 'password'
    response_401?
    body_includes 'Username taken.', 'test_username'
  end

  def test_login
    try_signup

    get '/login'
    response_200?
    body_includes 'Login', 'Username', 'Password', 'Submit'

    login_user
    response_302?
    follow_redirect!
    body_includes 'Welcome back, default!', "default's Subscriptions", 'Add Subscription'
  end

  def test_invalid_login
    login_user
    response_401?
    body_includes 'Invalid.', 'value="default"'
  end

  def test_not_logged_in
    not_logged_in_test
  end

  def test_index
    must_be_logged_in '/', nil

    get '/'
    response_200?
    refute_includes last_response.body, '</table>'
    body_includes 'Add Subscription', "You don't have any subscriptions to manage. Try adding one."

    add_subscription 'default', 'Harvard Business Review'
    get '/'
    response_200?
    body_includes 'Add Subscription', 'Harvard Business Review', '/harvard-business-review'
    
  end

  def test_new
    must_be_logged_in '/add'
    get '/add'
    response_200?
    body_includes 'Add New Subscription', '</form>',
                  '<button type="submit">Add</button>',
                  'frequency', 'cost', 'url'

    post '/add', 'name' => '/hbr', 'url' => 'www.hbr.com', 'cost' => '100.00', 'frequency' => '1'
    response_302?

    follow_redirect!
    expected_message = 'hbr has been added to your subscriptions.'
    body_includes 'hbr', expected_message

    get '/'
    refute_includes last_response.body, expected_message
  end

  def test_view_subscription
    must_be_logged_in '/hbr'
    add_subscription
    get '/hbr'
    response_200?
    body_includes 'hbr', 'www.hbr.com', '$100.00/year', '/hbr/edit', 'Edit'
  end

  def test_invalid_subscription
    must_be_logged_in '/hbr'
    get '/hbr'
    response_302?

    follow_redirect!
    response_200?
    body_includes 'Invalid Request.'
  end

  def test_sluggified_subscription
    must_be_logged_in '/slugify-me'
    add_subscription('default', 'Slugify Me!', 'www.slugify-me.com', '12', '10.99')

    get '/slugify-me'
    response_200?
    body_includes 'Slugify Me!', 'www.slugify-me.com', '$10.99/month'
  end

  def test_edit
    must_be_logged_in '/hbr/edit'
    add_subscription
    get '/hbr/edit'
    response_200?
    body_includes 'hbr', 'hbr', 'www.hbr.com', '100.00', '/hbr/edit', '<form', '<button type="submit">Update</button>'
  end

  def test_update_subscription
    must_be_logged_in '/hbr/edit'
    add_subscription

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
                  '$250.20/year', 'Harvard Business Review has been updated.', '/harvard-business-review'
  end

  def test_delete_subscription
    must_be_logged_in '/hbr'
    add_subscription

    get '/hbr'
    body_includes '/hbr', '/hbr/delete', 'Delete'

    post '/hbr/delete'
    response_302?
    follow_redirect!

    response_200?
    body_includes 'hbr was deleted.'

    get '/'
    refute_includes last_response.body, 'hbr'
  end

  def test_sanitize_url
    assert_equal 'www.google.com/something/', sanitize_url('www.google.com/something?name=some-value')
    assert_equal 'www.google.com/', sanitize_url('www.google.com/')
    assert_equal 'www.google.com/', sanitize_url('https://google.com')
  end
end






















