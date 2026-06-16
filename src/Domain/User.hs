module Domain.User
  ( User (..)
  , CreateUserRequest (..)
  , UpdateUserRequest (..)
  ) where

import Data.Aeson        (FromJSON (parseJSON), ToJSON (toEncoding, toJSON),
                          defaultOptions, genericParseJSON, genericToEncoding,
                          genericToJSON)
import Data.Aeson.Types  (Options (..))
import Data.Char         (isUpper, toLower)
import Data.Scientific   (Scientific)
import Data.Text         (Text)
import Data.Time         (UTCTime)
import Data.UUID         (UUID)
import GHC.Generics      (Generic)

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

data User = User
  { userId        :: UUID
  , userName      :: Text
  , userDocument  :: Text
  , userBalance   :: Scientific
  , userCurrency  :: Text
  , userCreatedAt :: UTCTime
  } deriving (Show, Eq, Generic)

instance ToJSON User where
  toJSON     = genericToJSON     (defaultOptions { fieldLabelModifier = dropPrefix "user" })
  toEncoding = genericToEncoding (defaultOptions { fieldLabelModifier = dropPrefix "user" })
instance FromJSON User where
  parseJSON = genericParseJSON   (defaultOptions { fieldLabelModifier = dropPrefix "user" })

data CreateUserRequest = CreateUserRequest
  { curName     :: Text
  , curDocument :: Text
  , curBalance  :: Scientific
  , curCurrency :: Text
  } deriving (Show, Eq, Generic)

instance ToJSON CreateUserRequest where
  toJSON     = genericToJSON     (defaultOptions { fieldLabelModifier = dropPrefix "cur" })
  toEncoding = genericToEncoding (defaultOptions { fieldLabelModifier = dropPrefix "cur" })
instance FromJSON CreateUserRequest where
  parseJSON = genericParseJSON   (defaultOptions { fieldLabelModifier = dropPrefix "cur" })

data UpdateUserRequest = UpdateUserRequest
  { uurName     :: Text
  , uurDocument :: Text
  } deriving (Show, Eq, Generic)

instance ToJSON UpdateUserRequest where
  toJSON     = genericToJSON     (defaultOptions { fieldLabelModifier = dropPrefix "uur" })
  toEncoding = genericToEncoding (defaultOptions { fieldLabelModifier = dropPrefix "uur" })
instance FromJSON UpdateUserRequest where
  parseJSON = genericParseJSON   (defaultOptions { fieldLabelModifier = dropPrefix "uur" })
