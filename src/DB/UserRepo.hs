{-# OPTIONS_GHC -Wno-orphans #-}
module DB.UserRepo
  ( findUserById
  , findUserByDocument
  , insertUser
  ) where

import Data.Pool                          (Pool)
import Data.Text                          (Text)
import Data.UUID                          (UUID)
import Database.PostgreSQL.Simple         (Connection, Only (..), execute,
                                           query)
import Database.PostgreSQL.Simple.FromRow (FromRow (..))

import DB.Connection (withConn)
import Domain.User   (User (..))


instance FromRow User

findUserById :: Pool Connection -> UUID -> IO (Maybe User)
findUserById pool uid = do
  rows <- withConn pool $ \conn ->
    query conn
      "SELECT id, name, document, created_at \
      \ FROM users WHERE id = ?"
      (Only uid)
  return $ case rows of
    [user] -> Just user
    _      -> Nothing

findUserByDocument :: Pool Connection -> Text -> IO (Maybe User)
findUserByDocument pool doc = do
  rows <- withConn pool $ \conn ->
    query conn
      "SELECT id, name, document, created_at \
      \ FROM users WHERE document = ?"
      (Only doc)
  return $ case rows of
    [user] -> Just user
    _      -> Nothing


insertUser :: Pool Connection -> UUID -> Text -> Text -> IO ()
insertUser pool uid uname udocument =
  withConn pool $ \conn ->
    execute conn
      "INSERT INTO users (id, name, document) \
      \ VALUES (?, ?, ?)"
      (uid, uname, udocument)
  >> return ()
