{-# LANGUAGE
    DataKinds
  #-}

module Control.Concurrent.STM.TChan.Typed.Extra where

import Control.Monad (forever)
import Control.Concurrent (threadDelay)
import Control.Concurrent.STM (STM, atomically)
-- import Control.Concurrent.STM.TVar (newTVar, readIORef, writeIORef)
import Control.Concurrent.STM.TMVar (newEmptyTMVar, tryTakeTMVar, putTMVar)
import Control.Concurrent.Chan.Scope (Scope (..))
import Control.Concurrent.STM.TChan.Typed (TChanRW, readTChanRW, writeTChanRW, newTChanRW, allowWriting, writeOnly)
import Control.Concurrent.Async (Async, async, cancel, wait)



type DiffNanosec = Int


-- | Note: In this model, even though we are using STM, a write to the
-- outgoing channel does not imply a transactional write to the output
-- channel; they are separated between a run IO layer, which means
-- we cannot atomically debounce or interleave the system (because
-- that depends on real-world time).
debounceStatic :: DiffNanosec -> TChanRW 'Read a -> IO (TChanRW 'Write a, Async ())
debounceStatic toWaitFurther outputChan = do
  (presentedChan,writingThread) <- atomically $ (,)
                                             <$> newTChanRW
                                             <*> newEmptyTMVar

  let invokeWrite x = do
        threadDelay toWaitFurther
        atomically $ writeTChanRW (allowWriting outputChan) x

  writer <- async $ forever $ do
    x <- atomically $ readTChanRW presentedChan

    newWriter <- async (invokeWrite x)

    mInvoker <- atomically $ tryTakeTMVar writingThread
    case mInvoker of
      Nothing -> pure ()
      Just i -> cancel i
    atomically $ putTMVar writingThread newWriter

  pure (writeOnly presentedChan, writer)


throttleStatic :: DiffNanosec -> TChanRW 'Read a -> IO (TChanRW 'Write a, Async ())
throttleStatic toWaitFurther outputChan = do
  (presentedChan,writingThread) <- atomically $ (,)
                                             <$> newTChanRW
                                             <*> newEmptyTMVar

  let invokeWrite x = do
        threadDelay toWaitFurther
        atomically $ writeTChanRW (allowWriting outputChan) x

  writer <- async $ forever $ do
    x <- atomically $ readTChanRW presentedChan

    mInvoker <- atomically $ tryTakeTMVar writingThread
    case mInvoker of
      Nothing -> pure ()
      Just i -> wait i
    newWriter <- async (invokeWrite x)
    atomically $ putTMVar writingThread newWriter

  pure (writeOnly presentedChan, writer)


intersperseStatic :: DiffNanosec -> IO a -> TChanRW 'Read a -> IO (TChanRW 'Write a, Async (), Async ())
intersperseStatic timeBetween xM outputChan = do
  (presentedChan,writingThread) <- atomically $ (,)
                                             <$> newTChanRW
                                             <*> newEmptyTMVar

  let invokeWritePing = do
        threadDelay timeBetween
        x <- xM
        atomically $ writeTChanRW (allowWriting outputChan) x

  writer <- async $ forever $ do
    mInvoker <- atomically $ tryTakeTMVar writingThread
    case mInvoker of
      Nothing -> pure ()
      Just i -> wait i
    newWriter <- async invokeWritePing
    atomically $ putTMVar writingThread newWriter

  listener <- async $ forever $ do
    (y,mInvoker) <- atomically $ do
      y' <- readTChanRW presentedChan

      (\q -> (y',q)) <$> tryTakeTMVar writingThread

    case mInvoker of
      Nothing -> pure ()
      Just i -> cancel i

    atomically $ writeTChanRW (allowWriting outputChan) y

  pure (writeOnly presentedChan, writer, listener)
