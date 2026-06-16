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
import Network.Wai.Middleware.Cors (CorsResourcePolicy (..), cors,
                                    simpleCorsResourcePolicy)
import Network.HTTP.Types.Method   (methodDelete, methodGet, methodOptions,
                                    methodPost, methodPut)
import Servant

import API.Types
import App.Env                     (AppEnv (..), AppM, dbPool)
import Authorizer.Mock             (mockAuthorize)
import DB.TransactionRepo          (findTransactionById, insertTransaction,
                                    updateTransactionStatus)
import DB.UserRepo                 (deleteUser, findUserById, findUserByDocument,
                                    hasTransactions, insertUser, listUsers,
                                    updateBalance, updateUser)
import Domain.Transaction          (CreateTransactionRequest (..), Transaction (..),
                                    TransactionStatus (..))
import Domain.User                 (CreateUserRequest (..), UpdateUserRequest (..), User (..))

appToHandler :: AppEnv -> AppM a -> Handler a
appToHandler env action =
  Handler . ExceptT . try $ runReaderT action env

paymentServer :: ServerT PaymentAPI AppM
paymentServer = healthHandler
             :<|> userServer
             :<|> transactionServer

userServer :: ServerT UserAPI AppM
userServer = createUserHandler
          :<|> listUsersHandler
          :<|> getUserHandler
          :<|> updateUserHandler
          :<|> deleteUserHandler

transactionServer :: ServerT TransactionAPI AppM
transactionServer = createTransactionHandler :<|> getTransactionHandler

healthHandler :: AppM String
healthHandler = return "OK"

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
            , userBalance   = curBalance req
            , userCurrency  = curCurrency req
            , userCreatedAt = now
            }
      liftIO $ insertUser pool uid (userName user) (userDocument user)
                                   (userBalance user) (userCurrency user)
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

createTransactionHandler :: CreateTransactionRequest -> AppM Transaction
createTransactionHandler req = do
  pool <- asks dbPool
  msender <- liftIO $ findUserById pool (ctrSenderId req)
  sender  <- case msender of
    Nothing -> liftIO $ throwIO err404 { errBody = "Sender not found" }
    Just s  -> return s
  mreceiver <- liftIO $ findUserById pool (ctrReceiverId req)
  receiver  <- case mreceiver of
    Nothing -> liftIO $ throwIO err404 { errBody = "Receiver not found" }
    Just r  -> return r
  if userCurrency sender /= userCurrency receiver
    then liftIO $ throwIO err422 { errBody = "Currency mismatch" }
    else do
      uid <- liftIO nextRandom
      now <- liftIO getCurrentTime
      let tx = Transaction
            { txId           = uid
            , txSenderId     = ctrSenderId req
            , txReceiverId   = ctrReceiverId req
            , txAmount       = ctrAmount req
            , txCurrencyCode = userCurrency sender
            , txInstallments = ctrInstallments req
            , txPanLastFour  = ctrPanLastFour req
            , txCardBrand    = ctrCardBrand req
            , txBillingEmail = ctrBillingEmail req
            , txIpAddress    = ctrIpAddress req
            , txResponseCode = Nothing
            , txStatus       = Pending
            , txCreatedAt    = now
            , txUpdatedAt    = now
            }
      liftIO $ insertTransaction pool tx
      if userBalance sender < ctrAmount req
        then do
          liftIO $ updateTransactionStatus pool uid Declined (Just "51")
          return tx { txStatus = Declined, txResponseCode = Just "51" }
        else do
          responseCode <- liftIO mockAuthorize
          let newStatus = case responseCode of
                "00" -> Approved
                "05" -> Declined
                "51" -> Declined
                _    -> Error
          case newStatus of
            Approved -> do
              liftIO $ updateBalance pool (ctrSenderId req) (negate (ctrAmount req))
              liftIO $ updateBalance pool (ctrReceiverId req) (ctrAmount req)
            _ -> return ()
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

corsPolicy :: CorsResourcePolicy
corsPolicy = simpleCorsResourcePolicy
  { corsOrigins        = Nothing
  , corsMethods        = [methodGet, methodPost, methodPut, methodDelete, methodOptions]
  , corsRequestHeaders = ["Content-Type", "Authorization"]
  }

makeApplication :: AppEnv -> Application
makeApplication env =
  cors (const $ Just corsPolicy) $
  serve userAPI $ hoistServer userAPI (appToHandler env) paymentServer
