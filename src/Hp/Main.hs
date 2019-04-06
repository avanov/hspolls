{-# LANGUAGE AllowAmbiguousTypes #-}

{-# OPTIONS_GHC -fno-warn-partial-type-signatures #-}

module Hp.Main where

import Hp.API
import Hp.Eff.HttpClient (HttpClient, runHttpManager)
import Hp.Env
import Hp.Form

import qualified Hp.GitHub
import qualified Hp.GitHub.AccessToken  as Hp.GitHub (AccessToken)
import qualified Hp.GitHub.ClientSecret as Hp.GitHub (ClientSecret(..))
import qualified Hp.GitHub.Response     as Hp.GitHub (Response(..))

import Control.Effect
-- import Control.Effect.Error
import Control.Effect.Reader
-- import Control.Monad.Trans.Except (ExceptT(..))
import System.IO (readFile)

import qualified Data.ByteString             as ByteString
import qualified Data.Text                   as Text
import qualified Network.HTTP.Client         as Http
import qualified Network.HTTP.Client.TLS     as Http (tlsManagerSettings)
import qualified Network.Wai                 as Wai
import qualified Network.Wai.Handler.Warp    as Warp
import qualified Servant                     as Servant
import qualified Servant.Client              as Servant
import qualified Servant.Server.Generic      as Servant
import qualified Text.Blaze.Html             as Blaze
import qualified Text.Blaze.Html5            as Blaze
import qualified Text.Blaze.Html5.Attributes as Blaze


main :: IO ()
main = do
  clientSecret :: [Char] <-
    readFile "github-client-secret" <|> pure "0xDEADBEEF"

  putStrLn "Running on port 8000"
  putStrLn ("Using GitHub client secret: " ++ clientSecret)

  httpManager :: Http.Manager <-
    Http.newManager Http.tlsManagerSettings

  Warp.run
    8000
    (application
      httpManager
      (Hp.GitHub.ClientSecret (Text.pack clientSecret)))

application ::
     Http.Manager
  -> Hp.GitHub.ClientSecret
  -> Wai.Request
  -> (Wai.Response -> IO Wai.ResponseReceived)
  -> IO Wai.ResponseReceived
application httpManager clientSecret =
  Servant.genericServeTWithContext
    η
    API
      { getLoginRoute = handleGetLogin
      , getLoginGitHubRoute = handleGetLoginGitHub @Env
      , postPollRoute = handlePostPoll
      }
    Servant.EmptyContext
  where
    η :: ∀ a. _ a -> Servant.Handler a
    η = runHttpManager @Env
      >>> runReader (Env httpManager clientSecret)
      -- >>> runError @Servant.ClientError
      >>> runM @IO
      -- >>> over (mapped . _Left) toServerError
      -- >>> ExceptT
      >>> liftIO
      >>> Servant.Handler

-- TODO Generalize to ApplicationException
-- TODO Implement toServerError
toServerError
  :: Servant.ClientError
  -> Servant.ServerError
toServerError = undefined

handleGetLogin ::
     ( Carrier sig m
     )
  => m Blaze.Html
handleGetLogin =
  -- TODO set state get param
  -- TODO set redirect_uri get param
  pure $
    Blaze.a "Log in with GitHub" Blaze.!
      Blaze.href
        (Blaze.unsafeByteStringValue
          (ByteString.concat
            [ "https://github.com/login/oauth/authorize?"
            , "allow_signup=false&"
            , "client_id=0708940f1632f7a953e8"
            ]))

handleGetLoginGitHub ::
     ∀ env m sig.
     ( Carrier sig m
     , HasType Hp.GitHub.ClientSecret env
     , Member HttpClient sig
     , Member (Reader env) sig
     , MonadIO m -- TODO axe this
     )
  => Text
  -> m Servant.NoContent
handleGetLoginGitHub code =
  doPostLoginOauthAccessToken >>= \case
    Left ex -> do
      liftIO (print ex) -- debug print for now
      pure Servant.NoContent

    Right (Hp.GitHub.ResponseError err) -> do
      liftIO (print err)
      pure Servant.NoContent

    Right (Hp.GitHub.ResponseSuccess accessToken) ->
      -- TODO finish oauth flow
      pure Servant.NoContent

  where
    doPostLoginOauthAccessToken ::
         m (Either SomeException (Hp.GitHub.Response Hp.GitHub.AccessToken))
    doPostLoginOauthAccessToken = do
      clientSecret :: Hp.GitHub.ClientSecret <-
        asks @env (^. typed)

      Hp.GitHub.postLoginOauthAccessToken
        Hp.GitHub.clientId
        (coerce clientSecret)
        code
        redirectUri
        state

    redirectUri :: Maybe Text
    redirectUri =
      -- TODO type safe link
      Just "http://localhost:8000/login/github"

    state :: Maybe Text
    state =
      -- TODO send random state
      Nothing

handlePostPoll ::
     ( Carrier sig m
     )
  => Form
  -> m Servant.NoContent
handlePostPoll _form =
  pure Servant.NoContent
