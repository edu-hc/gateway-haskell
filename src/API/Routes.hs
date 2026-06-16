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
import Network.Wai.Middleware.Cors (cors, corsRequestHeaders,
                                    corsMethods, corsOrigins,
                                    simpleCorsResourcePolicy,
                                    CorsResourcePolicy (..))
import Network.HTTP.Types.Method   (methodDelete, methodGet, methodPost,
                                    methodPut, methodOptions)
import Servant

import API.Types
import App.Env                     (AppEnv (..), AppM, dbPool)
import Authorizer.Mock             (mockAuthorize)
import DB.TransactionRepo          (findTransactionById, insertTransaction,
                                    updateTransactionStatus)
import DB.UserRepo                 (deleteUser, findUserById, findUserByDocument,
                                    hasTransactions, insertUser, listUsers,
                                    updateUser)
import Domain.Transaction          (CreateTransactionRequest (..),
                                    Transaction (..), TransactionStatus (..))
import Domain.User                 (CreateUserRequest (..), UpdateUserRequest (..),
                                    User (..))
import Vault.Repo                  (insertVaultEntry)
import Vault.Tokenizer             (PAN (..), Token (..), tokenize)

-- ---------------------------------------------------------------------------
-- Conversão AppM → Handler

appToHandler :: AppEnv -> AppM a -> Handler a
appToHandler env action = Handler . ExceptT . try $ runReaderT action env

-- ---------------------------------------------------------------------------
-- Servidor

paymentServer :: ServerT PaymentAPI AppM
paymentServer = healthHandler :<|> userServer :<|> transactionServer

healthHandler :: AppM String
healthHandler = return "OK"

userServer :: ServerT UserAPI AppM
userServer = createUserHandler
          :<|> listUsersHandler
          :<|> getUserHandler
          :<|> updateUserHandler
          :<|> deleteUserHandler

transactionServer :: ServerT TransactionAPI AppM
transactionServer = createTransactionHandler :<|> getTransactionHandler

-- ---------------------------------------------------------------------------
-- Handlers de usuário

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

listUsersHandler :: AppM [User]
listUsersHandler = do
  pool <- asks dbPool
  liftIO $ listUsers pool

getUserHandler :: UUID -> AppM User
getUserHandler uid = do
  pool  <- asks dbPool
  muser <- liftIO $ findUserById pool uid
  case muser of
    Just user -> return user
    Nothing   -> liftIO $ throwIO err404 { errBody = "User not found" }

updateUserHandler :: UUID -> UpdateUserRequest -> AppM User
updateUserHandler uid req = do
  pool  <- asks dbPool
  muser <- liftIO $ findUserById pool uid
  case muser of
    Nothing -> liftIO $ throwIO err404 { errBody = "User not found" }
    Just _  -> do
      mexisting <- liftIO $ findUserByDocument pool (uurDocument req)
      case mexisting of
        Just existing | userId existing /= uid ->
          liftIO $ throwIO err409 { errBody = "Document already exists" }
        _ -> do
          liftIO $ updateUser pool uid (uurName req) (uurDocument req)
          mupdated <- liftIO $ findUserById pool uid
          case mupdated of
            Just updated -> return updated
            Nothing      -> liftIO $ throwIO err500 { errBody = "Unexpected error" }

deleteUserHandler :: UUID -> AppM NoContent
deleteUserHandler uid = do
  pool  <- asks dbPool
  muser <- liftIO $ findUserById pool uid
  case muser of
    Nothing -> liftIO $ throwIO err404 { errBody = "User not found" }
    Just _  -> do
      hasTx <- liftIO $ hasTransactions pool uid
      if hasTx
        then liftIO $ throwIO err409 { errBody = "User has transactions" }
        else do
          liftIO $ deleteUser pool uid
          return NoContent

-- ---------------------------------------------------------------------------
-- Handlers de transação

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

-- ---------------------------------------------------------------------------
-- Application WAI

corsPolicy :: CorsResourcePolicy
corsPolicy = simpleCorsResourcePolicy
  { corsOrigins        = Nothing   -- permite qualquer origem
  , corsMethods        = [methodGet, methodPost, methodPut, methodDelete, methodOptions]
  , corsRequestHeaders = ["Content-Type", "Authorization"]
  }

makeApplication :: AppEnv -> Application
makeApplication env =
  cors (const $ Just corsPolicy) $
  serve userAPI $ hoistServer userAPI (appToHandler env) paymentServer
