require 'sinatra'
require 'sinatra/reloader'
require 'erubis'
require 'yaml'
require 'money'
require 'monetize'
require 'bcrypt'
require_relative 'html_helper'

# require 'pry'


configure do
  enable :sessions
  set :session_secret, 'secret'
end

FREQUENCY = {1=> 'year', 2=> 'six months', 4=>'quarter', 12=>'month'}
Money.use_i18n = false

helpers do
  def form_frequency(freq)
    return_text = ''
    FREQUENCY.each do |num, name|
      id = "f#{num}"
      return_text += "<input type='radio' name='frequency' id='#{id}' value='#{num}' #{"checked='checked'" if num == freq}/><label for='#{id}'>per #{name}</label>"
      return_text += "<br>" unless num == 12
    end
    return_text
  end

  def frequency_to_s(freq)
    FREQUENCY[freq]
  end

  def show_subscriptions
    table = HTML::Tag.new('table')
    thead = HTML::Tag.new('thead')
    headers = ['Subscription', '$ per Year']
    head_tr = HTML::Tag.new('tr')
    headers.each do |text|
      head_tr << HTML::Tag.new('th', text)
    end
    thead << head_tr
    table << thead

    tbody = HTML::Tag.new('tbody')
    total = Money.new(0,'USD')
    @subscriptions.each do |slug, values|
      body_tr = HTML::Tag.new('tr')
      sub = HTML::Tag.new('td')
      sub_link = HTML::Tag.new('a', values['name'], {'href'=>"/#{slug}", 'class' => 'link subscription'})
      sub << sub_link
      body_tr << sub
      cost = Money.new(values['cost'] * values['frequency'], 'USD')
      total += cost
      body_tr << HTML::Tag.new('td', "#{cost.format}")
      tbody << body_tr
    end
    table << tbody

    tfoot = HTML::Tag.new('tfoot')
    foot_tr = HTML::Tag.new('tr')
    foot_tr << HTML::Tag.new('th', 'Total')
    foot_tr << HTML::Tag.new('th', total.format)
    tfoot << foot_tr
    table << tfoot
    table.to_s
  end
end

# HELPERS----------------------------------------------------------------

def subscription_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/subscriptions.yml', __FILE__)
  else
    File.expand_path('../subscriptions.yml', __FILE__)
  end
end

def user_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/users.yml', __FILE__)
  else
    File.expand_path('../users.yml', __FILE__)
  end
end

def subscriptions_to_manage
  users_to_manage[session[:username]]['subscriptions']
end

def users_to_manage
  YAML.load_file(user_path) || {}
end

def update_users(users)
  File.open(user_path, 'w') { |f| f.write users.to_yaml}
end

def invalid_request(message='Invalid Request.')
  session[:message] = message
  redirect '/'
end

def subscription(sub_name)
  sub = subscriptions_to_manage[sub_name]
  @slug = sub_name
  @name = sub['name']
  @url = sub['url']
  @frequency = sub['frequency']
  @cost = Money.new(sub['cost'], 'USD')
end

def sluggify(name)
  name.downcase.gsub(/[^\s0-9A-z_]/,'').gsub(/\s/,'-')
end

def validate_cost
  @cost =~ /^[0-9]*\.{0,1}[\d]{0,2}$/
end

def validate_subscription_params
  @name && @frequency && @url && @cost &&
  @name.size > 0 &&
  validate_cost &&
  [1, 2, 4, 12].include?(@frequency) &&
  @url =~ /(http[s]{0,1}:\/\/){0,1}(www\.){0,1}([^\.]\S*)(\.([A-z]{1,3})(\/.*)*)/
end

def set_subscription_params
  @name = params[:name]
  @url = params[:url]
  @cost = params[:cost]
  @frequency = params[:frequency].to_i
end

def message(msg)
  session[:message] = msg
end

def validate_user
  valid_user = true
  password = params[:password]
  user = params[:username]

  valid_user &&= password.size >= 4 # Password must be 4 chars long
  valid_user &&= password.size <= 20 # Password no longer than 20 characters
  valid_user &&= user =~ /^[0-9A-z\-_]{3,20}$/# Only letters, numbers, hyphen and underscore, no spaces; Also, 3 to 20 characters
  if users_to_manage[user]
    message 'Username taken.'
    valid_user &&= false
  else
    message 'Invalid inputs.'
  end
  valid_user
end

def must_be_logged_in(message="You must be logged in!", &block)
  if session[:username]
    yield
  else
    session[:message] = message if message
    erb :default_index
    # halt
  end
end

def sanitize_url(url)
  url = url.split('?').first
  url = url.split(/https{0,1}\:\/\//)[-1]
  url = if url =~ /www\./
    url
  else
    "www.#{url}"
  end
  if url =~ /\/$/
    url
  else
    url + '/'
  end
end

# ROUTES ------------------------------------------------------------

get '/todo' do
  erb :todo
end

get '/' do
  must_be_logged_in(nil) do
    @subscriptions = subscriptions_to_manage
    erb :index
  end
end

get '/add' do
  must_be_logged_in { erb :add }
end

post '/add' do
  set_subscription_params
  if validate_subscription_params
    users = users_to_manage
    users[session[:username]]['subscriptions'][sluggify(@name)] = {'name' => @name, 'cost' => @cost.to_money.cents, 'frequency' => @frequency.to_i, 'url' => sanitize_url(@url)}
    update_users users

    session[:message] = "#{@name} has been added to your subscriptions."
    redirect '/'
  else
    session[:message] = "Invalid."
    status 400
    erb :add
  end
end

get '/signup' do
  erb :signup
end

post '/signup' do
  if validate_user
    users = users_to_manage
    users[params[:username]] = {'password' => BCrypt::Password.create(params[:password]), 'subscriptions' => {} }
    update_users users
    session[:username] = params[:username]
    session[:message] = "Welcome, #{params[:username]}!"
    redirect '/'
  else
    @username = params[:username]
    # session[:message] = 'Invalid inputs.'
    status 401
    erb :signup
  end
end

get '/login' do
  erb :login
end

post '/login' do
  users = users_to_manage
  username = params[:username]
  if users[username] && users[username]['password'] == params[:password]
    session[:message] = "Welcome back, #{username}!"
    session[:username] = username
    redirect '/'
  else
    @username = username
    session[:message] = "Invalid."
    status 401
    erb :login
  end
end

get '/logout' do
  session.delete :username
  redirect '/'
end

get '/:subscription' do
  must_be_logged_in do
    if subscriptions_to_manage.key? params[:subscription]
      subscription params[:subscription]
      erb :subscription
    else
      invalid_request
    end
  end
end

get '/:subscription/edit' do
  must_be_logged_in do
    if subscriptions_to_manage.key? params[:subscription]
      subscription params[:subscription]
      erb :edit
    else
      invalid_request
    end
  end
end

post '/:subscription/edit' do
  must_be_logged_in do
    set_subscription_params
    if validate_subscription_params
      users = users_to_manage
      users[session[:username]]['subscriptions'].delete(params[:subscription])
      slug = sluggify(@name)
      users[session[:username]]['subscriptions'][slug] = { 'name' => @name, 'cost' => @cost.to_money.cents, 'frequency' => @frequency.to_i, 'url' => sanitize_url(@url) }
      update_users users

      session[:message] = "#{@name} has been updated."
      redirect "/#{slug}"
    else
      session[:message] = 'Invalid.'
      erb :edit
    end
  end
end

post '/:subscription/delete' do
  must_be_logged_in do
    sub_to_delete = params[:subscription]

    if subscriptions_to_manage.include? sub_to_delete
      users = users_to_manage
      users[session[:username]]['subscriptions'].delete(sub_to_delete)
      update_users users
      session[:message] = "#{sub_to_delete} was deleted."
      redirect '/'
    else
      invalid_request
    end
  end
end



not_found do
  redirect '/'
end







