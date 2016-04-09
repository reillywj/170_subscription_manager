require 'sinatra'
require 'sinatra/reloader'
require 'erubis'
require 'yaml'
require 'money'
require_relative 'html_helper'

require 'pry'


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
  @name.size > 0 &&
  validate_cost &&
  [1, 2, 4, 12].include?(@frequency)
end

class String
  def to_cents
    dollars, cents = self.split('.')
    dollars = dollars.to_i * 100
    unless cents.nil?
      cents = cents + '0' if cents.size == 1
    end
    dollars + cents.to_i
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

get '/:subscription/edit' do
  if subscriptions_to_manage.key? params[:subscription]
    subscription params[:subscription]
    erb :edit
  else
    invalid_request
  end
end

post '/:subscription/edit' do
  set_subscription_params
  if validate_subscription_params
    subscriptions = subscriptions_to_manage
    subscriptions.delete params[:subscription]
    slug = sluggify @name
    subscriptions[slug] = { 'name' => @name, 'cost' => @cost.to_cents, 'frequency' => @frequency.to_i, 'url' => @url}
    update_subscriptions subscriptions

    session[:message] = "#{@name} has been updated."
    redirect "/#{slug}"
  else
    session[:message] = 'Invalid.'
    erb :edit
  end
end

post '/:subscription/delete' do
  sub_to_delete = params[:subscription]

  if subscriptions_to_manage.include? sub_to_delete
    subs = subscriptions_to_manage
    subs.delete sub_to_delete
    update_subscriptions subs
    session[:message] = "#{sub_to_delete} was deleted."
    redirect '/'
  else
    invalid_request
  end
end











