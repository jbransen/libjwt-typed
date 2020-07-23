--   This Source Code Form is subject to the terms of the Mozilla Public
--   License, v. 2.0. If a copy of the MPL was not distributed with this
--   file, You can obtain one at http://mozilla.org/MPL/2.0/.

{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}

module Libjwt.Header
  ( Alg(..)
  , Typ(..)
  , Header(..)
  , decodeHeader
  , matchAlg
  )
where

import           Libjwt.Encoding
import           Libjwt.Keys
import           Libjwt.FFI.Libjwt
import           Libjwt.FFI.Jwt

import           Control.Monad                  ( when )

import           Data.ByteString                ( ByteString )
import qualified Data.ByteString               as ByteString

import qualified Data.CaseInsensitive          as CI

data Alg = None
         | HS256 Secret
         | HS384 Secret
         | HS512 Secret
         | RS256 RsaKeyPair
         | RS384 RsaKeyPair
         | RS512 RsaKeyPair
         | ES256 EcKeyPair
         | ES384 EcKeyPair
         | ES512 EcKeyPair
  deriving stock (Show, Eq)

data Typ = JWT | Typ (Maybe ByteString)
  deriving stock (Show, Eq)

data Header = Header { alg :: Alg, typ :: Typ }
  deriving stock (Show, Eq)

instance Encode Header where
  encode header jwt = encodeAlg (alg header) jwt >> encodeTyp (typ header) jwt
   where
    encodeAlg None           = jwtSetAlg jwtAlgNone ByteString.empty >> forceTyp
    encodeAlg (HS256 secret) = jwtSetAlg jwtAlgHs256 $ reveal secret
    encodeAlg (HS384 secret) = jwtSetAlg jwtAlgHs384 $ reveal secret
    encodeAlg (HS512 secret) = jwtSetAlg jwtAlgHs512 $ reveal secret
    encodeAlg (RS256 pem   ) = jwtSetAlg jwtAlgRs256 $ privKey pem
    encodeAlg (RS384 pem   ) = jwtSetAlg jwtAlgRs384 $ privKey pem
    encodeAlg (RS512 pem   ) = jwtSetAlg jwtAlgRs512 $ privKey pem
    encodeAlg (ES256 pem   ) = jwtSetAlg jwtAlgEs256 $ ecPrivKey pem
    encodeAlg (ES384 pem   ) = jwtSetAlg jwtAlgEs384 $ ecPrivKey pem
    encodeAlg (ES512 pem   ) = jwtSetAlg jwtAlgEs512 $ ecPrivKey pem

    encodeTyp (Typ (Just s)) = addHeader "typ" s
    encodeTyp _              = nullEncode

    forceTyp = when (typ header == JWT) . addHeader "typ" "JWT"


decodeHeader :: Alg -> JwtT -> JwtIO Header
decodeHeader a = fmap (Header a) . decodeTyp
 where
  decodeTyp =
    fmap
        ( maybe (Typ Nothing)
        $ \s -> if CI.mk s == "jwt" then JWT else Typ $ Just s
        )
      . getHeader "typ"

matchAlg :: Alg -> JwtAlgT -> Bool
matchAlg (HS256 _) = (== jwtAlgHs256)
matchAlg (HS384 _) = (== jwtAlgHs384)
matchAlg (HS512 _) = (== jwtAlgHs512)
matchAlg (RS256 _) = (== jwtAlgRs256)
matchAlg (RS384 _) = (== jwtAlgRs384)
matchAlg (RS512 _) = (== jwtAlgRs512)
matchAlg (ES256 _) = (== jwtAlgEs256)
matchAlg (ES384 _) = (== jwtAlgEs384)
matchAlg (ES512 _) = (== jwtAlgEs512)
matchAlg None      = (== jwtAlgNone)