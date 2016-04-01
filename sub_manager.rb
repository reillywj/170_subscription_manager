require 'sinatra'
require 'sinatra/reloader'
require 'erubis'
require 'yaml'

require 'pry'


configure do
  enable :sessions
  set :session_secret, 'secret'
end

def subscription_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('./test/subscriptions.yml')
  else
    File.expand_path('./subscriptions.yml')
  end
end

def subscriptions_to_manage
  YAML.load_file subscription_path
end

def update_subscriptions(subscriptions)
  File.open(subscription_path, 'w') { |f| f.write subscriptions.to_yaml}
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
  name = params[:name]
  subscriptions = subscriptions_to_manage || {}
  subscriptions[name] = {}
  update_subscriptions subscriptions

  session[:message] = "#{name} has been added to your subscriptions."
  redirect '/'
end