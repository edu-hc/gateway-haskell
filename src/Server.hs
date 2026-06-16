module Server
  ( runServer
  ) where

import Control.Exception           (bracket)
import Data.Pool                   (destroyAllResources)
import Network.Wai.Handler.Warp    (run)
import System.Environment          (lookupEnv)
import System.IO                   (hPutStrLn, stderr)

import API.Routes    (makeApplication)
import App.Env       (AppEnv (..))
import DB.Connection (createPool)

getPort :: IO Int
getPort = do
  mport <- lookupEnv "PORT"
  return $ case mport of
    Just p  -> read p
    Nothing -> 8080

runServer :: IO ()
runServer =
  bracket createPool destroyAllResources $ \pool -> do
    port <- getPort
    let env = AppEnv { dbPool = pool }
    hPutStrLn stderr $ "Server starting on port " <> show port
    run port (makeApplication env)
