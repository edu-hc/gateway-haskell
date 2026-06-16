{-# OPTIONS_GHC -Wno-orphans #-}
module DB.UserRepo
  ( findUserById
  , findUserByDocument
  , insertUser
  , listUsers
  , updateUser
  , deleteUser
  , hasTransactions
  , updateBalance
  ) where

import Data.Pool                          (Pool)
import Data.Scientific                    (Scientific)
import Data.Text                          (Text)
import Data.UUID                          (UUID)
import Database.PostgreSQL.Simple         (Connection, Only (..), execute,
                                           query, query_)
import Database.PostgreSQL.Simple.FromRow (FromRow (..))

import DB.Connection (withConn)
import Domain.User   (User (..))

instance FromRow User

findUserById :: Pool Connection -> UUID -> IO (Maybe User)
findUserById pool uid = do
  rows <- withConn pool $ \conn ->
    query conn
      "SELECT id, name, document, balance, currency, created_at \
      \ FROM users WHERE id = ?"
      (Only uid)
  return $ case rows of
    [user] -> Just user
    _      -> Nothing

findUserByDocument :: Pool Connection -> Text -> IO (Maybe User)
findUserByDocument pool doc = do
  rows <- withConn pool $ \conn ->
    query conn
      "SELECT id, name, document, balance, currency, created_at \
      \ FROM users WHERE document = ?"
      (Only doc)
  return $ case rows of
    [user] -> Just user
    _      -> Nothing

insertUser :: Pool Connection -> UUID -> Text -> Text -> Scientific -> Text -> IO ()
insertUser pool uid uname udocument ubalance ucurrency =
  withConn pool $ \conn ->
    execute conn
      "INSERT INTO users (id, name, document, balance, currency) \
      \ VALUES (?, ?, ?, ?, ?)"
      (uid, uname, udocument, (realToFrac ubalance :: Double), ucurrency)
  >> return ()

listUsers :: Pool Connection -> IO [User]
listUsers pool =
  withConn pool $ \conn ->
    query_ conn
      "SELECT id, name, document, balance, currency, created_at \
      \ FROM users ORDER BY created_at DESC"

updateUser :: Pool Connection -> UUID -> Text -> Text -> IO ()
updateUser pool uid uname udocument =
  withConn pool $ \conn ->
    execute conn
      "UPDATE users SET name = ?, document = ? WHERE id = ?"
      (uname, udocument, uid)
  >> return ()

deleteUser :: Pool Connection -> UUID -> IO ()
deleteUser pool uid =
  withConn pool $ \conn ->
    execute conn
      "DELETE FROM users WHERE id = ?"
      (Only uid)
  >> return ()

hasTransactions :: Pool Connection -> UUID -> IO Bool
hasTransactions pool uid = do
  rows <- withConn pool $ \conn ->
    query conn
      "SELECT COUNT(*) FROM transactions \
      \ WHERE sender_id = ? OR receiver_id = ?"
      (uid, uid)
  return $ case rows of
    [Only (n :: Int)] -> n > 0
    _                 -> False

updateBalance :: Pool Connection -> UUID -> Scientific -> IO ()
updateBalance pool uid delta =
  withConn pool $ \conn ->
    execute conn
      "UPDATE users SET balance = balance + ? WHERE id = ?"
      (realToFrac delta :: Double, uid)
  >> return ()
