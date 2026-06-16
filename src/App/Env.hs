module App.Env
  ( AppEnv (..)
  , AppM
  ) where

import Control.Monad.Reader        (ReaderT)
import Data.Pool                   (Pool)
import Database.PostgreSQL.Simple  (Connection)

data AppEnv = AppEnv
  { dbPool :: Pool Connection
  }

type AppM = ReaderT AppEnv IO
