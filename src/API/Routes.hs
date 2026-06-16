module API.Routes
  ( makeApplication
  ) where

import Control.Exception           (throwIO, try)
import Control.Monad.Except        (ExceptT (..))
import Control.Monad.IO.Class      (liftIO)
import Control.Monad.Reader        (asks, runReaderT)
import Data.Text                   (pack)
import Data.Time                   (getCurrentTime)
import Data.UUID                   (UUID)
import Data.UUID.V4                (nextRandom)
import Servant

import API.Types
import App.Env                     (AppEnv (..), AppM, dbPool)
import Authorizer.Mock             (mockAuthorize)
import DB.TransactionRepo          (findTransactionById, insertTransaction,
                                    updateTransactionStatus)
import DB.UserRepo                 (findUserById, findUserByDocument,
                                    insertUser)
import Domain.Transaction          (CreateTransactionRequest (..),
                                    Transaction (..), TransactionStatus (..))
import Domain.User                 (CreateUserRequest (..), User (..))
import Vault.Repo                  (insertVaultEntry)
import Vault.Tokenizer             (PAN (..), Token (..), tokenize)


appToHandler :: AppEnv -> AppM a -> Handler a
appToHandler env action = Handler . ExceptT . try $ runReaderT action env


paymentServer :: ServerT PaymentAPI AppM
paymentServer = userServer :<|> transactionServer

userServer :: ServerT UserAPI AppM
userServer = createUserHandler :<|> getUserHandler

transactionServer :: ServerT TransactionAPI AppM
transactionServer = createTransactionHandler :<|> getTransactionHandler


createUserHandler :: CreateUserRequest -> AppM User
createUserHandler req = do
  pool      <- asks dbPool
  mexisting <- liftIO $ findUserByDocument pool (curDocument req)
  case mexisting of
    Just _  -> liftIO $ throwIO err409 { errBody = "Document already exists" }
    Nothing -> do
      uid <- liftIO nextRandom
      now <- liftIO getCurrentTime
      let user = User
            { userId        = uid
            , userName      = curName req
            , userDocument  = curDocument req
            , userCreatedAt = now
            }
      liftIO $ insertUser pool uid (userName user) (userDocument user)
      return user

getUserHandler :: UUID -> AppM User
getUserHandler uid = do
  pool  <- asks dbPool
  muser <- liftIO $ findUserById pool uid
  case muser of
    Just user -> return user
    Nothing   -> liftIO $ throwIO err404 { errBody = "User not found" }


createTransactionHandler :: CreateTransactionRequest -> AppM Transaction
createTransactionHandler req = do
  pool  <- asks dbPool
  muser <- liftIO $ findUserById pool (ctrUserId req)
  case muser of
    Nothing -> liftIO $ throwIO err404 { errBody = "User not found" }
    Just _  -> do
      token <- liftIO $ tokenize (PAN (ctrPan req))
      let Token tok = token
      liftIO $ insertVaultEntry pool token (ctrPan req) (ctrPanLastFour req) (ctrCardBrand req)
      uid <- liftIO nextRandom
      now <- liftIO getCurrentTime
      let tx = Transaction
            { txId           = uid
            , txUserId       = ctrUserId req
            , txAmount       = ctrAmount req
            , txCurrencyCode = ctrCurrencyCode req
            , txInstallments = ctrInstallments req
            , txPanLastFour  = ctrPanLastFour req
            , txCardBrand    = ctrCardBrand req
            , txCardToken    = tok
            , txBillingEmail = ctrBillingEmail req
            , txIpAddress    = ctrIpAddress req
            , txResponseCode = Nothing
            , txStatus       = Pending
            , txCreatedAt    = now
            , txUpdatedAt    = now
            }
      liftIO $ insertTransaction pool tx
      responseCode <- liftIO mockAuthorize
      let newStatus = case responseCode of
            "00" -> Approved
            "05" -> Declined
            "51" -> Declined
            _    -> Error
      liftIO $ updateTransactionStatus pool uid newStatus (Just (pack responseCode))
      return tx
        { txStatus       = newStatus
        , txResponseCode = Just (pack responseCode)
        }

getTransactionHandler :: UUID -> AppM Transaction
getTransactionHandler tid = do
  pool <- asks dbPool
  mtx  <- liftIO $ findTransactionById pool tid
  case mtx of
    Just tx -> return tx
    Nothing -> liftIO $ throwIO err404 { errBody = "Transaction not found" }


makeApplication :: AppEnv -> Application
makeApplication env =
  serve userAPI $ hoistServer userAPI (appToHandler env) paymentServer
