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
    <$> field
    <*> field
    <*> field
    <*> field
    <*> field
    <*> field
    <*> field
    <*> field
    <*> field
    <*> (unInetText <$> field)
    <*> field
    <*> (textToStatus <$> field)
    <*> field
    <*> field

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
      \ (id, sender_id, receiver_id, amount, currency_code, installments, \
      \  pan_last_four, card_brand, billing_email, \
      \  ip_address, status) \
      \ VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
      ( txId tx
      , txSenderId tx
      , txReceiverId tx
      , (realToFrac (txAmount tx) :: Double)
      , txCurrencyCode tx
      , txInstallments tx
      , txPanLastFour tx
      , txCardBrand tx
      , txBillingEmail tx
      , txIpAddress tx
      , statusToText (txStatus tx)
      )
  >> return ()

findTransactionById :: Pool Connection -> UUID -> IO (Maybe Transaction)
findTransactionById pool tid = do
  rows <- withConn pool $ \conn ->
    query conn
      "SELECT id, sender_id, receiver_id, amount, currency_code, installments, \
      \  pan_last_four, card_brand, billing_email, \
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
