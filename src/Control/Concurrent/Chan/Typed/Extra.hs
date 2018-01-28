{-# LANGUAGE
    DataKinds
  #-}

module Control.Concurrent.Chan.Typed.Extra where

import Data.IORef (newIORef, readIORef, writeIORef)
-- import Data.Time.Since (timeSince, newTimeSince)
import Control.Monad (forever)
import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar (newEmptyMVar, tryTakeMVar, putMVar)
import Control.Concurrent.Chan.Scope (Scope (..))
import Control.Concurrent.Chan.Typed (ChanRW, readChanRW, writeChanRW, newChanRW, writeOnly, allowWriting)
import Control.Concurrent.Async (Async, async, cancel, wait)



type DiffNanosec = Int

-- type TotalNanosec = Int


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

--         -- FIXME must use clocktime http://hackage.haskell.org/package/chan- overlayed invocations have
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

debounceStatic :: DiffNanosec -> ChanRW 'Read a -> IO (ChanRW 'Write a, Async ())
debounceStatic toWaitFurther outputChan = do
  presentedChan <- newChanRW
  writingThread <- newEmptyMVar

  let invokeWrite x = do
        threadDelay toWaitFurther
        writeChanRW (allowWriting outputChan) x

  writer <- async $ forever $ do
    x <- readChanRW presentedChan

    newWriter <- async (invokeWrite x)

    mInvoker <- tryTakeMVar writingThread
    case mInvoker of
      Nothing -> pure ()
      Just i -> cancel i
    putMVar writingThread newWriter

  pure (writeOnly presentedChan, writer)


-- | Like debounce, but lossless
throttleStatic :: DiffNanosec -> ChanRW 'Read a -> IO (ChanRW 'Write a, Async ())
throttleStatic toWaitFurther outputChan = do
  presentedChan <- newChanRW
  writingThread <- newEmptyMVar

  let invokeWrite x = do
        threadDelay toWaitFurther
        writeChanRW (allowWriting outputChan) x

  writer <- async $ forever $ do
    x <- readChanRW presentedChan

    mInvoker <- tryTakeMVar writingThread
    case mInvoker of
      Nothing -> pure ()
      Just i -> wait i
    newWriter <- async (invokeWrite x)
    putMVar writingThread newWriter

  pure (writeOnly presentedChan, writer)


intersperseStatic :: DiffNanosec -> IO a -> ChanRW 'Read a -> IO (ChanRW 'Write a, Async (), Async ())
intersperseStatic timeBetween xM outputChan = do
  presentedChan <- newChanRW
  writingThread <- newEmptyMVar

  let invokeWritePing = do
        threadDelay timeBetween
        x <- xM
        writeChanRW (allowWriting outputChan) x

  writer <- async $ forever $ do
    mInvoker <- tryTakeMVar writingThread
    case mInvoker of
      Nothing -> pure ()
      Just i -> wait i
    newWriter <- async invokeWritePing
    putMVar writingThread newWriter

  listener <- async $ forever $ do
    y <- readChanRW presentedChan

    mInvoker <- tryTakeMVar writingThread
    case mInvoker of
      Nothing -> pure ()
      Just i -> cancel i

    writeChanRW (allowWriting outputChan) y

  pure (writeOnly presentedChan, writer, listener)
