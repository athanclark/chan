# chan

This is just some extra `Chan` and `TChan` kit that might help the average user. It relies on
spawning threads with `async` and either canceling (debouncing) or waiting (throttling) messages.

Unfortunately, the current design is untyped in the sense that the channel which you supply is the
_output_ channel, and the returned channel is the one you would write to. I'm not sure how this should
be fixed.

An example might be the following:

```haskell
import Control.Concurrent.Chan (readChan)
import Control.Concurrent.Chan.Extra (throttleStatic, intersperseStatic)



-- For example, some websockets:

data SomeMessage
  = Ping
  -- | ...

throttleLayer :: Chan SomeMessage -> IO (Chan SomeMessage)
throttleLayer output = do
  (x,_) <- throttleStatic output 1000000 -- nanoseconds, = 1 second
  pure x

pingLayer :: Chan SomeMessage -> IO (Chan SomeMessage)
pingLayer output = do
  (x,_,_) <- intersperseStatic output (pure Ping) 1000000
  pure x

performWebsocket :: Chan SomeMessage -> IO ()
performWebsocket output = do
  output' <- pingLayer =<< throttleLayer output
  _ <- async $ forever $ do
    msg <- readChan output'
    send msg -- something like that - it'll include Ping messages for us,
             -- and throttle the outgoing messages at the same time.
```
