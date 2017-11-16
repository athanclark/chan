module Control.Concurrent.STM.TChan.Extra where

import Control.Monad (forever)
import Control.Concurrent (threadDelay)
import Control.Concurrent.STM (STM, atomically)
-- import Control.Concurrent.STM.TVar (newTVar, readIORef, writeIORef)
import Control.Concurrent.STM.TMVar (newEmptyTMVar, tryTakeTMVar, putTMVar)
import Control.Concurrent.STM.TChan (TChan, readTChan, writeTChan, newTChan)
import Control.Concurrent.Async (Async, async, cancel, wait)



type DiffNanosec = Int


-- | Note: In this model, even though we are using STM, a write to the
-- outgoing channel does not imply a transactional write to the output
-- channel; they are separated between a run IO layer, which means
-- we cannot atomically debounce or interleave the system (because
-- that depends on real-world time).
debounceStatic :: DiffNanosec -> TChan a -> IO (TChan a, Async ())
debounceStatic toWaitFurther outputChan = do
  (presentedChan,writingThread) <- atomically $ (,)
                                             <$> newTChan
                                             <*> newEmptyTMVar

  let invokeWrite x = do
        threadDelay toWaitFurther
        atomically $ writeTChan outputChan x

  writer <- async $ forever $ do
    x <- atomically $ readTChan presentedChan

    newWriter <- async (invokeWrite x)

    mInvoker <- atomically $ tryTakeTMVar writingThread
    case mInvoker of
      Nothing -> pure ()
      Just i -> cancel i
    atomically $ putTMVar writingThread newWriter

  pure (presentedChan, writer)



intersperseStatic :: DiffNanosec -> IO a -> TChan a -> IO (TChan a, Async (), Async ())
intersperseStatic timeBetween xM outputChan = do
  (presentedChan,writingThread) <- atomically $ (,)
                                             <$> newTChan
                                             <*> newEmptyTMVar

  let invokeWritePing = do
        threadDelay timeBetween
        x <- xM
        atomically $ writeTChan outputChan x

  writer <- async $ forever $ do
    mInvoker <- atomically $ tryTakeTMVar writingThread
    case mInvoker of
      Nothing -> pure ()
      Just i -> wait i
    newWriter <- async invokeWritePing
    atomically $ putTMVar writingThread newWriter

  listener <- async $ forever $ do
    (y,mInvoker) <- atomically $ do
      y' <- readTChan presentedChan

      (\q -> (y',q)) <$> tryTakeTMVar writingThread

    case mInvoker of
      Nothing -> pure ()
      Just i -> cancel i

    atomically $ writeTChan outputChan y

  pure (presentedChan, writer, listener)
