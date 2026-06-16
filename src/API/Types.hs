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
import Domain.User        (CreateUserRequest, UpdateUserRequest, User)

-- ---------------------------------------------------------------------------
-- Rotas de usuário

type UserAPI
     = "users" :> ReqBody '[JSON] CreateUserRequest  :> Post   '[JSON] User
  :<|> "users" :> Get '[JSON] [User]
  :<|> "users" :> Capture "id" UUID                  :> Get    '[JSON] User
  :<|> "users" :> Capture "id" UUID :> ReqBody '[JSON] UpdateUserRequest :> Put '[JSON] User
  :<|> "users" :> Capture "id" UUID                  :> DeleteNoContent

-- ---------------------------------------------------------------------------
-- Rotas de transação

type TransactionAPI
     = "transactions" :> ReqBody '[JSON] CreateTransactionRequest :> Post '[JSON] Transaction
  :<|> "transactions" :> Capture "id" UUID :> Get '[JSON] Transaction

-- ---------------------------------------------------------------------------
-- API completa

type PaymentAPI = UserAPI :<|> TransactionAPI

userAPI :: Proxy PaymentAPI
userAPI = Proxy
