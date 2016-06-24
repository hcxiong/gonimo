{-# LANGUAGE OverloadedStrings #-}

import           Language.PureScript.Bridge

import Control.Lens
import           Data.Proxy
import           GHC.Generics
import           Servant.PureScript

import           Gonimo.CodeGen.TypeBridges
import           Gonimo.Server.DbEntities
import           Gonimo.WebAPI
import           Gonimo.Types
import           Gonimo.Client.Types as Client

data GonimoBridge

instance HasBridge GonimoBridge where
  languageBridge _ = buildBridge gonimoBridge


gonimoProxy :: Proxy GonimoBridge
gonimoProxy = Proxy

data TestTypeConstructor m a = TestTypeConstructor (m a) deriving Generic

myTypes :: [SumType 'Haskell]
myTypes = [
        mkSumType (Proxy :: Proxy Client.AuthData)
      , mkSumType (Proxy :: Proxy AuthToken)
      , mkSumType (Proxy :: Proxy Coffee)
      , mkSumType (Proxy :: Proxy Invitation)
      , mkSumType (Proxy :: Proxy InvitationDelivery)
      , mkSumType (Proxy :: Proxy SendInvitation)
      ]

mySettings :: Settings
mySettings = addReaderParam "AuthToken" defaultSettings & apiModuleName .~ "Gonimo.WebAPI"


main :: IO ()
main = do
  let gonimoFrontPath = "../gonimo-front/src"
  writePSTypes gonimoFrontPath (buildBridge gonimoBridge) myTypes
  writeAPIModuleWithSettings mySettings gonimoFrontPath gonimoProxy gonimoAPI
