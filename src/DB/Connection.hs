module DB.Connection
  ( createPool
  , withConn
  ) where

import Control.Exception           (throwIO)
import Data.Pool                   (Pool, defaultPoolConfig, newPool,
                                    withResource)
import Data.String                 (fromString)
import Database.PostgreSQL.Simple  (Connection, close, connectPostgreSQL)
import System.Environment          (lookupEnv)

getEnvOrFail :: String -> IO String
getEnvOrFail key = do
  mval <- lookupEnv key
  case mval of
    Just val -> return val
    Nothing  -> throwIO $ userError $ "Missing env var: " <> key

createPool :: IO (Pool Connection)
createPool = do
  url <- getEnvOrFail "DATABASE_URL"
  newPool $ defaultPoolConfig
    (connectPostgreSQL (fromString url))
    close
    30
    10

withConn :: Pool Connection -> (Connection -> IO a) -> IO a
withConn = withResource
