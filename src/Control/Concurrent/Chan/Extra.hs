module Control.Concurrent.Chan.Extra where

import Data.IORef (newIORef, readIORef, writeIORef)
-- import Data.Time.Since (timeSince, newTimeSince)
import Control.Monad (forever)
import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar (newEmptyMVar, tryTakeMVar, putMVar)
import Control.Concurrent.Chan (Chan, readChan, writeChan, newChan)
import Control.Concurrent.Async (Async, async, cancel)



type DiffNanosec = Int

type TotalNanosec = Int


-- debounceDynamic :: (NominalDiffTime -> NominalDiffTime) -> Chan a -> IO (Chan a, Async ())
-- debounceDynamic toWait outputChan = do
--   sinceRef <- newTimeSince
--   totalWaited <- newIORef 0
--   presentedChan <- newChan
--   writingThread <- newEmptyMVar

--   let invokeWrite x = do
--         putStrLn "Being run.."

--         waited <- readIORef totalWaited
--         let toWaitFurther = toWait waited
--         writeIORef totalWaited (waited + toWaitFurther)

--         -- FIXME must use clocktime - overlayed invocations have
--         -- no concept of time spent, only have knoweldge of invocations
--         -- made

--         threadDelay toWaitFurther
--         putStrLn "waited done"
--         writeChan outputChan x

--   writer <- async $ forever $ do
--     x <- readChan presentedChan

--     newWriter <- async (invokeWrite x)

--     mInvoker <- tryTakeMVar writingThread
--     case mInvoker of
--       Nothing -> pure ()
--       Just i -> cancel i
--     print "killed"
--     putMVar writingThread newWriter

--   pure (presentedChan, writer)

debounceStatic :: DiffNanosec -> Chan a -> IO (Chan a, Async ())
debounceStatic toWaitFurther outputChan = do
  presentedChan <- newChan
  writingThread <- newEmptyMVar

  let invokeWrite x = do
        threadDelay toWaitFurther
        writeChan outputChan x

  writer <- async $ forever $ do
    x <- readChan presentedChan

    newWriter <- async (invokeWrite x)

    mInvoker <- tryTakeMVar writingThread
    case mInvoker of
      Nothing -> pure ()
      Just i -> cancel i
    putMVar writingThread newWriter

  pure (presentedChan, writer)
