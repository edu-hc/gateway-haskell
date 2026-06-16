{-# LANGUAGE DataKinds     #-}
{-# LANGUAGE TypeOperators #-}
module API.Types
  ( UserAPI
  , TransactionAPI
  , PaymentAPI
  , userAPI
  ) where

import Data.UUID  (UUID)
import Servant

import Domain.Transaction (CreateTransactionRequest, Transaction)
import Domain.User        (CreateUserRequest, User)


type UserAPI
     = "users" :> ReqBody '[JSON] CreateUserRequest :> Post '[JSON] User
  :<|> "users" :> Capture "id" UUID :> Get '[JSON] User


type TransactionAPI
     = "transactions" :> ReqBody '[JSON] CreateTransactionRequest :> Post '[JSON] Transaction
  :<|> "transactions" :> Capture "id" UUID :> Get '[JSON] Transaction


type PaymentAPI = UserAPI :<|> TransactionAPI

userAPI :: Proxy PaymentAPI
userAPI = Proxy
