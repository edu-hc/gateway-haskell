module Domain.Transaction
  ( Transaction (..)
  , TransactionStatus (..)
  , CreateTransactionRequest (..)
  ) where

import Data.Aeson       (FromJSON (parseJSON), ToJSON (toEncoding, toJSON),
                         defaultOptions, genericParseJSON, genericToEncoding,
                         genericToJSON)
import Data.Aeson.Types (Options (..))
import Data.Char        (isUpper, toLower, toUpper)
import Data.Scientific  (Scientific)
import Data.Text        (Text)
import Data.Time        (UTCTime)
import Data.UUID        (UUID)
import GHC.Generics     (Generic)

dropPrefix :: String -> String -> String
dropPrefix prefix f =
  let stripped = drop (length prefix) f
      lowered  = case stripped of
                   []     -> []
                   (c:cs) -> toLower c : cs
  in camelToSnake lowered
  where
    camelToSnake []     = []
    camelToSnake (c:cs)
      | isUpper c = '_' : toLower c : camelToSnake cs
      | otherwise = c : camelToSnake cs


data TransactionStatus
  = Pending
  | Approved
  | Declined
  | Error
  deriving (Show, Eq, Generic)

statusOptions :: Options
statusOptions = defaultOptions
  { constructorTagModifier = map toUpper }

instance ToJSON TransactionStatus where
  toJSON     = genericToJSON     statusOptions
  toEncoding = genericToEncoding statusOptions

instance FromJSON TransactionStatus where
  parseJSON = genericParseJSON statusOptions


data Transaction = Transaction
  { txId           :: UUID
  , txUserId       :: UUID
  , txAmount       :: Scientific
  , txCurrencyCode :: Text
  , txInstallments :: Int
  , txPanLastFour  :: Text
  , txCardBrand    :: Text
  , txCardToken    :: Text
  , txBillingEmail :: Text
  , txIpAddress    :: Text
  , txResponseCode :: Maybe Text
  , txStatus       :: TransactionStatus
  , txCreatedAt    :: UTCTime
  , txUpdatedAt    :: UTCTime
  } deriving (Show, Eq, Generic)

txOptions :: Options
txOptions = defaultOptions { fieldLabelModifier = dropPrefix "tx" }

instance ToJSON Transaction where
  toJSON     = genericToJSON     txOptions
  toEncoding = genericToEncoding txOptions

instance FromJSON Transaction where
  parseJSON = genericParseJSON txOptions


data CreateTransactionRequest = CreateTransactionRequest
  { ctrUserId       :: UUID
  , ctrAmount       :: Scientific
  , ctrCurrencyCode :: Text
  , ctrInstallments :: Int
  , ctrPan          :: Text
  , ctrPanLastFour  :: Text
  , ctrCardBrand    :: Text
  , ctrBillingEmail :: Text
  , ctrIpAddress    :: Text
  } deriving (Show, Eq, Generic)

ctrOptions :: Options
ctrOptions = defaultOptions { fieldLabelModifier = dropPrefix "ctr" }

instance ToJSON CreateTransactionRequest where
  toJSON     = genericToJSON     ctrOptions
  toEncoding = genericToEncoding ctrOptions

instance FromJSON CreateTransactionRequest where
  parseJSON = genericParseJSON ctrOptions
