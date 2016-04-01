require 'sinatra'
require 'sinatra/reloader'
require 'erubis'


configure do
  enable :sessions
  set :session_secret, 'secret'
end

get '/todo' do
  erb :todo
end

get '/' do
  erb :index
end