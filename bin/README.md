# Simulating an Event
This is a script that will help simulate an event to your `ngrok`
tunnel. In order for this to work, you need to:

Start `ngrok`:

`ngrok 4567`

Setup the following variables in the `.env` file. You will want to
capture the `Forwarding` URL from the `ngrok` output:

```
WEBHOOK_HOST="http://{key}.ngrok.com"
WEBHOOK_PATH="/hooks/automatic"
```

And...

Have your `sinatra` server up and running:

```
bundle exec server.rb
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
