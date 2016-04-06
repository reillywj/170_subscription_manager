require 'sinatra'
require 'sinatra/reloader'
require 'erubis'
require 'yaml'
require 'money'

require 'pry'


configure do
  enable :sessions
  set :session_secret, 'secret'
end

FREQUENCY = {1=> 'year', 2=> 'six months', 4=>'quarter', 12=>'month'}
Money.use_i18n = false

def subscription_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/subscriptions.yml', __FILE__)
  else
    File.expand_path('../subscriptions.yml', __FILE__)
  end
end

def subscriptions_to_manage
  YAML.load_file(subscription_path) || {}
end

def update_subscriptions(subscriptions)
  File.open(subscription_path, 'w') { |f| f.write subscriptions.to_yaml}
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
  @frequency = FREQUENCY[sub['frequency']]
  @cost = Money.new(sub['cost'], 'USD')
end

def sluggify(name)
  name.downcase.gsub(/[^\s0-9A-z_]/,'').gsub(/\s/,'-')
end

def validate_cost
  @cost =~ /^[0-9]*\.{0,1}[\d]{0,2}$/
end

def validate_subscription_params
  @name.size > 0 &&
  validate_cost &&
  [1, 2, 4, 12].include?(@frequency)
end

class String
  def to_cents
    dollars, cents = self.split('.')
    dollars.to_i * 100 + cents.to_i
  end
end

def set_subscription_params
  @name = params[:name]
  @url = params[:url]
  @cost = params[:cost]
  @frequency = params[:frequency].to_i
end

get '/todo' do
  erb :todo
end

get '/' do
  @subscriptions = subscriptions_to_manage
  erb :index
end

get '/add' do
  erb :add
end

post '/add' do
  set_subscription_params
  if validate_subscription_params
    subscriptions = subscriptions_to_manage
    subscriptions[sluggify @name] = {'name' => @name, 'cost' => @cost.to_cents, 'frequency' => @frequency.to_i, 'url' => @url}
    update_subscriptions subscriptions

    session[:message] = "#{@name} has been added to your subscriptions."
    redirect '/'
  else
    session[:message] = "Invalid."
    erb :add
  end
end

get '/:subscription' do
  if subscriptions_to_manage.key? params[:subscription]
    subscription params[:subscription]
    erb :subscription
  else
    invalid_request
  end
end
