import Control.Monad (forever)
import Control.Concurrent (threadDelay)
import Control.Concurrent.Chan (newChan, writeChan, readChan)
import Control.Concurrent.Chan.Extra (debounceStatic, intersperseStatic)
import Control.Concurrent.Async (async)
import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)

main :: IO ()
main = do

  outgoing <- newChan
  (incoming, _) <- debounceStatic 1000000 outgoing

  lock <- newEmptyMVar

  _ <- async $ forever $ do
    x <- readChan outgoing
    print x
    putMVar lock ()

  putStrLn "writing 1..."
  writeChan incoming 1

  _ <- takeMVar lock

  putStrLn "writing 2..."
  writeChan incoming 1
  writeChan incoming 2

  _ <- takeMVar lock



  outgoing <- newChan
  (incoming, _, _) <- intersperseStatic 1000000 (pure 0) outgoing

  lock <- newEmptyMVar

  _ <- async $ forever $ do
    x <- readChan outgoing
    print x
    putMVar lock ()

  threadDelay 3000000

  putStrLn "Writing 1..."
  writeChan incoming 1
  _ <- takeMVar lock
  putStrLn "writing 2..."
  writeChan incoming 2
  _ <- takeMVar lock

  pure ()
