{-# OPTIONS_GHC -Wno-orphans #-}
module DB.TransactionRepo
  ( insertTransaction
  , findTransactionById
  , updateTransactionStatus
  ) where

import Data.Pool                                      (Pool)
import Data.Text                                      (Text)
import Data.Text.Encoding                             (decodeUtf8)
import Data.UUID                                      (UUID)
import Database.PostgreSQL.Simple                     (Connection, Only (..),
                                                       execute, query)
import Database.PostgreSQL.Simple.FromField           (FromField (..),
                                                       ResultError (..),
                                                       returnError)
import Database.PostgreSQL.Simple.FromRow             (FromRow (..), field)

import DB.Connection       (withConn)
import Domain.Transaction  (Transaction (..), TransactionStatus (..))

-- ---------------------------------------------------------------------------
-- FromField INET → Text
-- postgresql-simple não converte INET automaticamente para Text.

newtype InetText = InetText { unInetText :: Text }

instance FromField InetText where
  fromField f mbs = case mbs of
    Nothing -> returnError UnexpectedNull f ""
    Just bs -> return $ InetText (decodeUtf8 bs)


textToStatus :: Text -> TransactionStatus
textToStatus "APPROVED" = Approved
textToStatus "DECLINED" = Declined
textToStatus "ERROR"    = Error
textToStatus _          = Pending

instance FromRow Transaction where
  fromRow = Transaction
    <$> field                        -- id            :: UUID
    <*> field                        -- user_id       :: UUID
    <*> field                        -- amount        :: Scientific
    <*> field                        -- currency_code :: Text
    <*> field                        -- installments  :: Int
    <*> field                        -- pan_last_four :: Text
    <*> field                        -- card_brand    :: Text
    <*> field                        -- card_token    :: Text
    <*> field                        -- billing_email :: Text
    <*> (unInetText <$> field)       -- ip_address    :: Text (via INET)
    <*> field                        -- response_code :: Maybe Text
    <*> (textToStatus <$> field)     -- status        :: TransactionStatus
    <*> field                        -- created_at    :: UTCTime
    <*> field                        -- updated_at    :: UTCTime


statusToText :: TransactionStatus -> Text
statusToText Pending  = "PENDING"
statusToText Approved = "APPROVED"
statusToText Declined = "DECLINED"
statusToText Error    = "ERROR"


insertTransaction :: Pool Connection -> Transaction -> IO ()
insertTransaction pool tx =
  withConn pool $ \conn ->
    execute conn
      "INSERT INTO transactions \
      \ (id, user_id, amount, currency_code, installments, \
      \  pan_last_four, card_brand, card_token, billing_email, \
      \  ip_address, status) \
      \ VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
      ( txId tx
      , txUserId tx
      , (realToFrac (txAmount tx) :: Double)
      , txCurrencyCode tx
      , txInstallments tx
      , txPanLastFour tx
      , txCardBrand tx
      , txCardToken tx
      , txBillingEmail tx
      , txIpAddress tx
      , statusToText (txStatus tx)
      )
  >> return ()

findTransactionById :: Pool Connection -> UUID -> IO (Maybe Transaction)
findTransactionById pool tid = do
  rows <- withConn pool $ \conn ->
    query conn
      "SELECT id, user_id, amount, currency_code, installments, \
      \  pan_last_four, card_brand, card_token, billing_email, \
      \  ip_address, response_code, status, created_at, updated_at \
      \ FROM transactions WHERE id = ?"
      (Only tid)
  return $ case rows of
    [tx] -> Just tx
    _    -> Nothing

updateTransactionStatus
  :: Pool Connection
  -> UUID
  -> TransactionStatus
  -> Maybe Text
  -> IO ()
updateTransactionStatus pool tid status responseCode =
  withConn pool $ \conn ->
    execute conn
      "UPDATE transactions \
      \ SET status = ?, response_code = ?, updated_at = NOW() \
      \ WHERE id = ?"
      ( statusToText status
      , responseCode
      , tid
      )
  >> return ()
