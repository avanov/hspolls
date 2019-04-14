module Hp.Event.PollAnswered where

import Hp.Entity            (Entity)
import Hp.Entity.PollAnswer (PollAnswer)


-- | A poll was answered.
newtype PollAnsweredEvent
  = PollAnsweredEvent
  { answer :: Entity PollAnswer
  } deriving stock (Generic, Show)
