{-# LANGUAGE
    DataKinds
  , KindSignatures
  #-}

module Control.Concurrent.STM.TChan.Typed where

import Control.Concurrent.Chan.Scope (Scope (..), Writable, Readable)
import Control.Concurrent.STM.TChan (TChan)
import qualified Control.Concurrent.STM.TChan as TChan
import Control.Concurrent.STM (STM)


newtype TChanRW (scope :: Scope) a = TChanRW (TChan a)


readOnly :: Readable scope => TChanRW scope a -> TChanRW 'Read a
readOnly (TChanRW c) = TChanRW c

writeOnly :: Writable scope => TChanRW scope a -> TChanRW 'Write a
writeOnly (TChanRW c) = TChanRW c

allowReading :: Writable scope => TChanRW scope a -> TChanRW 'ReadWrite a
allowReading (TChanRW c) = TChanRW c

allowWriting :: Readable scope => TChanRW scope a -> TChanRW 'ReadWrite a
allowWriting (TChanRW c) = TChanRW c


newTChanRW :: STM (TChanRW 'ReadWrite a)
newTChanRW = TChanRW <$> TChan.newTChan


writeTChanRW :: Writable scope => TChanRW scope a -> a -> STM ()
writeTChanRW (TChanRW c) x = TChan.writeTChan c x


unGetTChanRW :: Writable scope => TChanRW scope a -> a -> STM ()
unGetTChanRW (TChanRW c) x = TChan.unGetTChan c x


isEmptyTChanRW :: Readable scope => TChanRW scope a -> STM Bool
isEmptyTChanRW (TChanRW c) = TChan.isEmptyTChan c


readTChanRW :: Readable scope => TChanRW scope a -> STM a
readTChanRW (TChanRW c) = TChan.readTChan c


tryReadTChanRW :: Readable scope => TChanRW scope a -> STM (Maybe a)
tryReadTChanRW (TChanRW c) = TChan.tryReadTChan c


peekTChanRW :: Readable scope => TChanRW scope a -> STM a
peekTChanRW (TChanRW c) = TChan.peekTChan c


tryPeekTChanRW :: Readable scope => TChanRW scope a -> STM (Maybe a)
tryPeekTChanRW (TChanRW c) = TChan.tryPeekTChan c


newBroadcastTChanRW :: STM (TChanRW 'Write a)
newBroadcastTChanRW = TChanRW <$> TChan.newBroadcastTChan


dupTChanRW :: Writable scopeIn
           => Readable scopeOut
           => TChanRW scopeIn a -> STM (TChanRW scopeOut a)
dupTChanRW (TChanRW c) = TChanRW <$> TChan.dupTChan c


cloneTChanRW :: Writable scopeIn
           => Readable scopeOut
           => TChanRW scopeIn a -> STM (TChanRW scopeOut a)
cloneTChanRW (TChanRW c) = TChanRW <$> TChan.cloneTChan c
