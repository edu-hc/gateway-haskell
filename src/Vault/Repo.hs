module Vault.Repo
  ( insertVaultEntry
  , findPANByToken
  ) where

import Data.Pool                          (Pool)
import Data.Text                          (Text)
import Database.PostgreSQL.Simple         (Connection, Only (..), execute,
                                           query)

import DB.Connection   (withConn)
import Vault.Tokenizer (Token (..))

insertVaultEntry
  :: Pool Connection
  -> Token
  -> Text          -- pan
  -> Text          -- pan_last_four
  -> Text          -- card_brand
  -> IO ()
insertVaultEntry pool (Token tok) pan lastFour brand =
  withConn pool $ \conn ->
    execute conn
      "INSERT INTO card_vault (token, pan, pan_last_four, card_brand) \
      \ VALUES (?, ?, ?, ?)"
      (tok, pan, lastFour, brand)
  >> return ()

findPANByToken :: Pool Connection -> Token -> IO (Maybe Text)
findPANByToken pool (Token tok) = do
  rows <- withConn pool $ \conn ->
    query conn
      "SELECT pan FROM card_vault WHERE token = ?"
      (Only tok)
  return $ case rows of
    [Only pan] -> Just pan
    _          -> Nothing
