module Hp.PollAnswer where

import Hp.PollItemAnswer (PollItemAnswer)

import Data.Aeson (FromJSON)


newtype PollAnswer
  = PollAnswer { unPollAnswer :: Seq PollItemAnswer }
  deriving newtype (FromJSON)