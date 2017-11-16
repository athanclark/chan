module Control.Concurrent.Chan.Extra where

import Data.IORef (newIORef, readIORef, writeIORef)
import Control.Monad (forever)
import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar (newEmptyMVar, tryTakeMVar, putMVar)
import Control.Concurrent.Chan (Chan, readChan, writeChan, newChan)
import Control.Concurrent.Async (Async, async, cancel)



type DiffNanosec = Int

type TotalNanosec = Int


debounce :: (TotalNanosec -> DiffNanosec) -> Chan a -> IO (Chan a, Async ())
debounce toWait outputChan = do
  totalWaited <- newIORef 0
  presentedChan <- newChan
  writingThread <- newEmptyMVar

  let invokeWrite x = do
        putStrLn "Being run.."

        waited <- readIORef totalWaited
        let toWaitFurther = toWait waited
        writeIORef totalWaited (waited + toWaitFurther)

        -- FIXME must use clocktime - overlayed invocations have
        -- no concept of time spent, only have knoweldge of invocations
        -- made

        threadDelay toWaitFurther
        putStrLn "waited done"
        writeChan outputChan x

  writer <- async $ forever $ do
    x <- readChan presentedChan

    newWriter <- async (invokeWrite x)

    mInvoker <- tryTakeMVar writingThread
    case mInvoker of
      Nothing -> pure ()
      Just i -> cancel i
    print "killed"
    putMVar writingThread newWriter

  pure (presentedChan, writer)
