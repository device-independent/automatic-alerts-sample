# Simulating an Event
This is a script that will help simulate an event to your `ngrok`
tunnel. In order for this to work, you need to:

* Have your _Sinatra_ server up and running: `bundle exec server.rb`
* Have `ngrok` up and running: `ngrok 4567`

Setup the following variables in the `.env` file:

```
WEBHOOK_HOST="http://{key}.ngrok.com"
WEBHOOK_PATH="/hooks/automatic"
```

You can then issue commands to the script from the _root_ of the
directory.

```
bundle exec bin/simulate event --name 'notification:speeding'
```

You can get more information with:

```
bundle exec bin/simulate help event
```

There are sample `json` files that have been used from the [Automatic
Developer Documentation Sample Event
Objects](https://www.automatic.com/developer/documentation/#sample-event-objects)
