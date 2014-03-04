require 'sinatra'
require 'multi_json'
require File.expand_path('../library.rb', __FILE__)

post '/hooks/automatic' do
  # Read the incoming body
  body_content = request.body.read
  json_content = MultiJson.load(body_content)

  # Choose lights to trigger for the alerts. See Huey for setup and connection information.
  light_groups = [Huey::Group.new('Basement')]

  # Choose numbers to text for the alerts. They must be `verified` numbers with Twilio.
  sms_numbers = []

  # Instantiate an instance of the Incoming Webhook Event
  event = Automatic::Events::Instance.new(json_content)

  # Setup custom alerts for the Hue Lights
  light_groups.each do |group|
    event.add_alert(Alerts::Lights.new(event, group.bulbs))
  end

  # Have the OSX System `say` command speak the event
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
