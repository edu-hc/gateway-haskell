module Vault.Tokenizer
  ( PAN (..)
  , Token (..)
  , tokenize
  ) where

import Data.Text      (Text, pack)
import Data.UUID.V4   (nextRandom)


newtype PAN   = PAN   Text deriving (Show, Eq)
newtype Token = Token Text deriving (Show, Eq)


tokenize :: PAN -> IO Token
tokenize _ = do
  uid <- nextRandom
  return $ Token $ "tok_" <> pack (show uid)
