require 'multi_json'
require 'huey'
require 'twilio-ruby'

require 'dotenv'
Dotenv.load

module Automatic
  module Events
    class Instance
      def initialize(attributes={})
        @attributes = attributes
      end

      def add_alert(alert)
        alert_registration.use(alert)
      end

      def alert!
        alert_registration.alert!
      end

      def type
        @attributes.fetch('type', nil)
      end

      def phrase
        event_phrase
      end

      def write!
        File.open('webhook-events.json', 'a+') do |file|
          line = "%s\n" % [MultiJson.dump(@attributes)]
          file.write(line)
        end
      end

      private
      def alert_registration
        @alert_registration ||= Alerts::Registration.new
      end

      def event_phrase
        case(self.type.to_s)
        when 'ignition:on'
          'Ignition on'
        when 'ignition:off'
          'Ignition off'
        when 'parking:changed'
          'Parking has changed'
        when 'region:changed'
          'Region has changed'
        when 'trip:finished'
          'Trip has finished'
        when 'notification:speeding'
          'Speeding'
        when 'notification:hard_accel'
          'Hard acceleration'
        when 'notification:hard_brake'
          'Hard brake'
        when 'mil:on'
          'Check engine light on'
        when 'mil:off'
          'Check engine light off'
        else
          'No idea what happened'
        end
      end
    end
  end
end

module Alerts
  class Registration
    InvalidAlertError = Class.new(StandardError)

    attr_reader :alerts

    include Enumerable

    def initialize
      @alerts = []
    end

    def use(alert)
      raise InvalidAlertError.new('Must respond to #alert!') unless alert.respond_to?(:alert!)
      @alerts << alert
    end

    def alerts?
      self.alerts.any?
    end

    def alert!
      threads = alert_threads
      threads.each { |thread| thread.join }
    end

    private
    def alert_threads
      self.alerts.map do |alert|
        Thread.new do
          alert.alert!
        end
      end
    end
  end

  class SMS
    def initialize(event, to)
      @event = event
      @to    = to
    end

    def alert!
      client.account.messages.create(sms_params)
    end

    private
    def client
      @client ||= Twilio::REST::Client.new(ENV.fetch('TWILIO_ACCOUNT_SID'), ENV.fetch('TWILIO_AUTH_TOKEN'))
    end

    def sms_params
      {
        :from => ENV.fetch('TWILIO_FROM_NUMBER'),
        :to   => @to,
        :body => @event.phrase
      }
    end
  end

  class Screamer
    def initialize(event)
      @event = event
    end

    def alert!
      cmd = "say %s" % [@event.phrase]
      system(cmd)
    end
  end

  class Lights
    COLOR_BLUE  = '#2E37FE'
    COLOR_RED   = '#FF0000'
    COLOR_GREEN = '#32B141'

    TRANSITION_TIME = 10

    def initialize(event, lights)
      @event  = event
      @lights = lights
    end

    def alert!
      case(event_type.to_s)
      when 'default', 'ignition:on', 'ignition:off', 'parking:changed', 'trip:finished'
        threads = @lights.map do |light|
          Thread.new do
            light.update(alert: :none, bri: 20, on: true, rgb: COLOR_GREEN, transitiontime: TRANSITION_TIME)
          end
        end
        threads.each { |thread| thread.join }
      when 'notification:speeding'
        total_lights = @lights.count
        half_lights  = (total_lights / 2)

        red_lights  = @lights[0, half_lights]
        blue_lights = @lights[half_lights, total_lights]

        threads    = []
        time_limit = 20

        red_lights.inject(threads) do |arr,light|
          arr << Thread.new do
            i = 0
            while(i < time_limit) do
              light.update(alert: :lselect, on: true, rgb: COLOR_RED, transitiontime: 0)
              i += 1
            end
            light.update(alert: :none, on: true, rgb: COLOR_GREEN, transitiontime: 0)
          end
          arr
        end

        blue_lights.inject(threads) do |arr,light|
          arr << Thread.new do
            i = 0
            while(i < time_limit) do
              light.update(alert: :lselect, on: true, rgb: COLOR_BLUE, transitiontime: 0)
              i += 1
            end
            light.update(alert: :none, on: true, rgb: COLOR_GREEN, transitiontime: 0)
          end
          arr
        end

        threads.each { |thread| thread.join }
      when 'notification:hard_accel', 'notification:hard_brake'
        threads = @lights.map do |light|
          Thread.new do
            light.update(alert: :none, bri: 255, rgb: COLOR_BLUE, on: true, transitiontime: TRANSITION_TIME)
          end
        end
        threads.each { |thread| thread.join }
      end
    end

    private
    def event_type
      @event.type
    end
  end
end
