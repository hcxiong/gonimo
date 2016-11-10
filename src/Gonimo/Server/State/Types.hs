{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleInstances #-}

module Gonimo.Server.State.Types where


import           Control.Concurrent.STM    (TVar)
import           Control.Lens
import           Control.Monad.Except      (ExceptT, runExceptT)
import           Control.Monad.Trans.Maybe
import           Control.Monad.Trans.State (StateT (..))
import           Data.Aeson.Types          (FromJSON (..), FromJSON,
                                            ToJSON (..), ToJSON (..),
                                            Value (String), defaultOptions,
                                            genericToEncoding, genericToJSON)
import           Data.Map.Strict           (Map)
import qualified Data.Map.Strict           as M
import           Data.Text                 (Text)
import           GHC.Generics              (Generic)
import           Servant.PureScript     (jsonParseHeader, jsonParseUrlPiece)
import           Web.HttpApiData        (FromHttpApiData (..))

import           Gonimo.Server.Db.Entities (DeviceId, FamilyId)
import           Gonimo.Server.Types      (DeviceType, Secret)

type FromId = DeviceId
type ToId   = DeviceId

-- | For online session to identify a particular session
newtype SessionId = SessionId Int deriving (Ord, Eq, Show, Generic)

instance ToJSON SessionId where
  toJSON     = genericToJSON defaultOptions
  toEncoding = genericToEncoding defaultOptions
instance FromJSON SessionId

instance FromHttpApiData SessionId where
    parseUrlPiece = jsonParseUrlPiece
    parseHeader   = jsonParseHeader


-- | Writers wait for the receiver to receive a message,
-- | the reader then signals that is has read it's message
-- | and the writer afterwards removes the message. In case the receiver does not
-- | receive the message in time, the writer also removes the message.
-- | The reader never removes a message, because then it would be possible
-- | that the writer deletes someone elses message in case of a timeout.
-- |
-- | The message could already have been received and replaced by a new one and we would delete
-- | a message sent by someone else. This would have been a really nasty bug *phooooh*
data QueueStatus a = Written a | Read deriving (Eq, Show)
$(makePrisms ''QueueStatus)

-- | Baby station calls receiveSocket: Map of it's client id to the requester's client id and the channel secret.
type ChannelSecrets = Map ToId (QueueStatus (FromId, Secret))

type ChannelData a  = Map (FromId, ToId, Secret) (QueueStatus a)

data FamilyOnlineState = FamilyOnlineState
                       { _channelSecrets :: ChannelSecrets
                       , _channelData    :: ChannelData Text
                       , _sessions  :: Map DeviceId (SessionId, DeviceType)
                       , _idCounter :: Int -- Used for SessionId's currently
                       } deriving (Show, Eq)

$(makeLenses ''FamilyOnlineState)

type FamilyMap = Map FamilyId (TVar FamilyOnlineState)

type OnlineState = TVar FamilyMap

type UpdateFamilyT m a = StateT FamilyOnlineState m a
type MayUpdateFamily a = UpdateFamilyT (MaybeT Identity) a
type UpdateFamily a = UpdateFamilyT Identity a

emptyFamily :: FamilyOnlineState
emptyFamily = FamilyOnlineState {
    _channelSecrets = M.empty
  , _channelData = M.empty
  , _sessions = M.empty
  , _idCounter = 0
  }