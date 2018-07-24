require 'rubygems'
require 'bundler/setup'
require 'mechanize'
require 'net/http'
require 'json'

require 'pp'
require 'byebug'

CLIENT_ID=ENV["CLIENT_ID"]
CLIENT_SECRET=ENV["CLIENT_SECRET"]
REDIRECT_URI=ENV["REDIRECT_URI"]

USERNAME=ENV["USERNAME"]
PASSWORD=ENV["PASSWORD"]

ORG_NAME=ENV["ORG_NAME"]

# Authorizes against the Teem API. Required before any API actions.
# Returns the Teem API JSON object containing the access token.
def teem_authorize
  # Enable this for Mechanize debugging
  #Mechanize.log = Logger.new $stderr

  browser = Mechanize.new { |agent|
    agent.user_agent_alias = 'Mac Safari'
  }

  # Load the sign-in page
  page = browser.get("https://app.teem.com/oauth/authorize/?client_id=#{CLIENT_ID}&redirect_uri=#{REDIRECT_URI}&response_type=code&scope=users")

  # Find the link to sign in via SSO
  sign_in_link = page.links.find { |link| link.text.include? 'Sign In with Company SSO' }

  # Click that link
  page = sign_in_link.click
  
  # We will be prompted for our organization
  org_ask_form = page.forms[0]
  org_ask_form.fields[0].value = ORG_NAME

  # Submit that form
  page = browser.submit(page.forms.first)

  # We should be on the SSO login page now. Fill it out.
  f = page.forms[0]
  f.field_with(:name => "UserName").value = USERNAME
  f.field_with(:name => "Password").value = PASSWORD
  page = f.submit

  # We are now at a weird, no-where-place page that we just need to submit (SAML stuff?)
  f = page.forms.first
  page = f.submit

  # We should now be at teem.com being asked to Authorize
  f = page.forms.first
  authorize_btn = f.button_with(:value => 'Authorize')

  the_code = nil

  # This will take us back to our Roles page, which doesn't exist
  begin
    page = browser.submit(f, authorize_btn)
  rescue  Mechanize::ResponseCodeError => e
    regex_results = /code=(\w+)/.match(e.to_s)

    the_code = regex_results[1]
  end

  url = "https://app.teem.com/oauth/token/?client_id=#{CLIENT_ID}&client_secret=#{CLIENT_SECRET}&grant_type=authorization_code&redirect_uri=#{REDIRECT_URI}&code=#{the_code}"
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Post.new(uri.request_uri)
  response = http.request(request)

  json = JSON.parse(response.body)

  return json
end

def teem_get_users(access_token)
  uri = URI.parse("https://app.teem.com/api/v4/accounts/users/")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  req = Net::HTTP::Get.new(uri.request_uri)

  req.add_field("Authorization", "Bearer #{access_token}")
  res = http.request(req)
  
  return JSON.parse(res.body)["users"]
end

# json = teem_authorize()
# access_token = json["access_token"]
# puts "access_token: #{access_token}"
access_token = "oxNGDIQ0Pm2VeSV8ZdacXaBfG1TIeO"

users = teem_get_users(access_token)

users.each do |user|
  puts user["email"]
end
