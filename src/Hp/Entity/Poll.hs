module Hp.Entity.Poll
  ( Poll(..)
  , EntityId(..)
  , PollId
  , pollIdDecoder
  , pollIdEncoder
  , pollQuestions
  , isPollExpired
  ) where

import Hp.Eff.GetCurrentTime (GetCurrentTimeEffect, getCurrentTime)
import Hp.Entity.User        (UserId)
import Hp.IsEntity           (IsEntity(..))
import Hp.PollFormElement    (PollFormElement(..))
import Hp.PollQuestion       (PollQuestion)

import Control.Effect
import Data.Aeson      (FromJSON, ToJSON)
import Data.Time       (DiffTime, NominalDiffTime, UTCTime, diffUTCTime)
import Data.UUID       (UUID)
import Web.HttpApiData (FromHttpApiData)

import qualified Hasql.Decoders as Decoder
import qualified Hasql.Encoders as Encoder


data Poll
  = Poll
  { created :: UTCTime
  , duration :: DiffTime
  , elements :: [PollFormElement]
  , userId :: Maybe UserId
  } deriving stock (Generic, Show)

instance IsEntity Poll where
  newtype EntityId Poll
    = PollId { unPollId :: UUID }
    deriving stock (Show)
    deriving newtype (FromHttpApiData, FromJSON, ToJSON)

type PollId
  = EntityId Poll

pollIdDecoder :: Decoder.Value PollId
pollIdDecoder =
  PollId <$> Decoder.uuid

pollIdEncoder :: Encoder.Value PollId
pollIdEncoder =
  coerce Encoder.uuid

-- | Extract just the questions from a poll.
pollQuestions ::
     Poll
  -> [PollQuestion]
pollQuestions poll =
  [ question | QuestionElement question <- poll ^. #elements ]

-- | Is this poll expired?
isPollExpired ::
     ( Carrier sig m
     , Member GetCurrentTimeEffect sig
     )
  => Poll
  -> m Bool
isPollExpired poll = do
  now :: UTCTime <-
    getCurrentTime

  let
    elapsed :: NominalDiffTime
    elapsed =
      now `diffUTCTime` (poll ^. #created)

  pure (elapsed >= realToFrac (poll ^. #duration))
