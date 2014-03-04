# Automatic Link Notifications

## Goal
Utilize the Automatic API, specifically the [webhooks](https://www.automatic.com/developer/documentation/#automatic-event-webhook-api), and integrating with other services such as [Philips Hue](http://developers.meethue.com) and [Twilio](http://www.twilio.com/docs/api/rest).

## Tools

* [Automatic Link](http://www.automatic.com) for your vehicle and an account to access the API.
* [Twilio](http://www.twilio.com) account to send SMS messages. (optional)
* [Philips Hue](https://www.meethue.com) starter kit and bulbs. (optional)
* [Sinatra](http://www.sinatrarb.com) as a simple web server to receive `localhost` requests.
* [ngrok](https://ngrok.com) to create a tunnel to `localhost`.
* I am using **OSX** to perform all tasks.
* I am using [Ruby](https://www.ruby-lang.org/en/) and [RVM](https://rvm.io) for my Ruby version manager.

## Steps
Here are the steps I took to integrate multiple _alert_ services with my Automatic Link.

### Application and Dependencies
I started by creating a folder that will house the code dependencies and server.

    mkdir -p ~/Sites/automatic-webhooks
    cd ~/Sites/automatic-webhooks
    echo "2.0.0" > .ruby-version
    echo "automatic-webhooks" > .ruby-gemset
    echo "source 'https://rubygems.org'" > Gemfile
    cd ../
    cd automatic-webhooks # CD out and in to pick up the Ruby Version and Gemset.

Once you have this base you can begin to add the necessary dependencies to the `Gemfile`. Here is what my `Gemfile` looks like:

    source 'https://rubygems.org'
    
    gem 'sinatra'
    gem 'huey'
    gem 'twilio-ruby'
    gem 'dotenv'
    gem 'multi_json'

Here's some more info on each:

* [`sinatra`](https://rubygems.org/gems/sinatra) is the application webserver.
* [`huey`](https://rubygems.org/gems/huey) is a base gem I use to handle connects with the Hue Bridge.
* [`twilio-ruby`](https://rubygems.org/gems/twilio-ruby) is the ruby wrapper for Twilio.
* [`dotenv`](https://rubygems.org/gems/dotenv) is a gem to help manage `ENV` variables within your app. This prevents hardcoding any tokens or credentials.
* [`multi_json`](http://rubygems.org/gems/multi_json) for fast JSON parsing.

### ngrok
First you want to [download](https://ngrok.com/download) and install ngrok. You can follow the steps on the download page to install for your OS. Once you are up and running, you can start `ngrok` with

    ngrok 4567

I use **4567** as it's the default port for the _Sinatra_ web server. You will get a response that looks like:

  
    ngrok
    
    Tunnel Status online
    Version       1.6/1.5
    Forwarding    http://{key}.ngrok.com -> 127.0.0.1:4567
    Forwarding    https://{key}.ngrok.com -> 127.0.0.1:4567
    Web Interface 127.0.0.1:4040

`ngrok` is now up and running and tunneling requests. Now we need to turn on the web server.

### Sinatra
I chose _Sinatra_ for it's quickness and simplicity. _Rails_ would also be a sufficient server.

I instantiate a simple server to capture the _webhooks_ with the following `server.rb` file:

```ruby
require 'sinatra'
require 'multi_json'
require File.expand_path('../library.rb', __FILE__)

post '/hooks/automatic' do
  content_type :json
  
  body_content = request.body.read
  json_content = JSON.parse(body_content)
  
  puts json_content.inspect
  
  status(200)
  body(nil)
end
```

I'll explain some more of the underlying code in a minute. For now, I start my `sinatra` server with:

    bundle exec ruby server.rb

If all is successful you will receive the output:

    [2014-03-03 14:33:54] INFO  WEBrick 1.3.1
    [2014-03-03 14:33:54] INFO  ruby 2.0.0 (2014-02-24) [x86_64-darwin12.5.0]
    == Sinatra/1.4.4 has taken the stage on 4567 for development with backup from WEBrick
    [2014-03-03 14:33:54] INFO  WEBrick::HTTPServer#start: pid=87759 port=4567

The `sinatra` server is now up and running. You can do a quick test to ensure `ngrok` is properly tunneling requests to `sinatra` with:

    curl 'http://{key}.ngrok.com/hooks/automatic' -X POST -d '{}'

Your `sinatra` output will recognize the request and respond:

    127.0.0.1 - - [03/Mar/2014 14:35:38] "POST /hooks/automatic HTTP/1.1" 200 - 1.9406
    localhost - - [03/Mar/2014:14:35:36 EST] "POST /hooks/automatic HTTP/1.1" 200 0
    - -> /hooks/automatic
    
And `ngrok` will show the request:

    HTTP Requests                                                         
    -------------                                                         
    POST /hooks/automatic         200 OK  
    
All is good. You now have a tunnel to your local instance of `sinatra`. Now you need to register this with the folks at _Automatic_. You will register an **Application** with them and specify the **Webhook URL** to be your `ngrok` instance:

    http://{key}.ngrok.com/hooks/automatic
    
You will replace `key` with the address you are assigned from `ngrok`. Once they get this setup and in place you can use their web interface to _simulate webhook event_ and pick from an event to simulate. If all is working well, as soon as you hit **Simulate** you will see the request come through to your local application server.

## Handling the Response
Now is where we will begin to fill out our `/hooks/automatic` route. In order to handle the response, we will utilize a few `Alert` objects and some wrappers to our API's. Here's what the route will look like:

```ruby
post '/hooks/automatic' do
  # Read the incoming body
  body_content = request.body.read
  json_content = MultiJson.load(body_content)

  # Choose lights to trigger for the alerts
  light_groups = [Huey::Group.new('Basement')]

  # Choose numbers to text for the alerts
  sms_numbers = []

  # Instantiate an instance of the Incoming Webhook Event
  event = Automatic::Events::Instance.new(json_content)

  # Setup custom alerts for the Hue Lights
  light_groups.each do |group|
    event.add_alert(Alerts::Lights.new(event, group.bulbs))
  end

  # Have the OSX System `say` commend speak the event
  event.add_alert(Alerts::Screamer.new(event))

  # Send an SMS to specified numbers
  sms_numbers.each do |number|
    event.add_alert(Alerts::SMS.new(event, number))
  end

  # Write the alert to a JSON cache file
  event.write!

  # Trigger the alerts
  event.alert!

  # Return a successful response
  status(200)
  body(nil)
end
```

Again, for simplicity, the code for this is stored in `library.rb`. Normally we would separate out the concerns and gemify certain aspects. This is intentionally a rough proof-of-concept.
