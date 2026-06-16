module Domain.User
  ( User (..)
  , CreateUserRequest (..)
  ) where

import Data.Aeson    (FromJSON (parseJSON), ToJSON (toJSON, toEncoding),
                      Options (..), defaultOptions,
                      genericParseJSON, genericToEncoding, genericToJSON)
import Data.Char     (isUpper, toLower)
import Data.Text     (Text)
import Data.Time     (UTCTime)
import Data.UUID     (UUID)
import GHC.Generics  (Generic)

-- strips a camelCase prefix then converts the remainder to snake_case,
-- replicating the behaviour of aesonPrefix snakeCase from aeson-casing
jsonOpts :: String -> Options
jsonOpts prefix = defaultOptions
  { fieldLabelModifier = toSnake . decap . drop (length prefix) }
  where
    decap []     = []
    decap (c:cs) = toLower c : cs
    toSnake []     = []
    toSnake (c:cs)
      | isUpper c  = '_' : toLower c : toSnake cs
      | otherwise  = c : toSnake cs

-- | User persistido no banco
data User = User
  { userId        :: UUID
  , userName      :: Text
  , userDocument  :: Text
  , userCreatedAt :: UTCTime
  } deriving (Show, Eq, Generic)

instance ToJSON User where
  toJSON     = genericToJSON     (jsonOpts "user")
  toEncoding = genericToEncoding (jsonOpts "user")
instance FromJSON User where
  parseJSON = genericParseJSON (jsonOpts "user")

data CreateUserRequest = CreateUserRequest
  { curName     :: Text
  , curDocument :: Text
  } deriving (Show, Eq, Generic)

instance ToJSON CreateUserRequest where
  toJSON     = genericToJSON     (jsonOpts "cur")
  toEncoding = genericToEncoding (jsonOpts "cur")
instance FromJSON CreateUserRequest where
  parseJSON = genericParseJSON (jsonOpts "cur")
