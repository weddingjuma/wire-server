{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ViewPatterns      #-}

module Network.Wire.Client.API.Conversation
    ( postOtrMessage
    , createConv
    , getConv
    , addMembers
    , removeMember
    , memberUpdate
    , module M
    ) where

import Bilge
import Data.ByteString.Conversion
import Data.Id
import Data.Foldable (toList)
import Data.List.NonEmpty hiding (cons, toList)
import Data.List1
import Data.Text (Text)
import Galley.Types as M hiding (Event, EventType)
import Network.HTTP.Types.Method
import Network.HTTP.Types.Status hiding (statusCode)
import Network.Wire.Client.HTTP
import Network.Wire.Client.Session
import Network.Wire.Client.API.Push (ConvEvent)

postOtrMessage :: MonadSession m => ConvId -> NewOtrMessage -> m ClientMismatch
postOtrMessage cnv msg = sessionRequest req rsc readBody
  where
    req = method POST
        . paths ["conversations", toByteString' cnv, "otr", "messages"]
        . acceptJson
        . json msg
        $ empty
    rsc = status201 :| [status412]

addMembers :: MonadSession m => ConvId -> List1 UserId -> m (Maybe (ConvEvent Members))
addMembers cnv mems = do
    rs <- sessionRequest req rsc consumeBody
    case statusCode rs of
        200 -> Just <$> fromBody rs
        204 -> return Nothing
        _   -> unexpected rs "addMembers: status code"
  where
    req = method POST
        . paths ["conversations", toByteString' cnv, "members"]
        . acceptJson
        . json (Invite mems)
        $ empty
    rsc = status200 :| [status204]

removeMember :: MonadSession m => ConvId -> UserId -> m (Maybe (ConvEvent Members))
removeMember cnv mem = do
    rs <- sessionRequest req rsc consumeBody
    case statusCode rs of
        200 -> Just <$> fromBody rs
        204 -> return Nothing
        _   -> unexpected rs "removeMember: status code"
  where
    req = method DELETE
        . paths ["conversations", toByteString' cnv, "members", toByteString' mem]
        . acceptJson
        $ empty
    rsc = status200 :| [status204]

memberUpdate :: MonadSession m => ConvId -> MemberUpdateData -> m ()
memberUpdate cnv updt = sessionRequest req rsc (const $ return ())
  where
    req = method PUT
        . paths ["conversations", toByteString' cnv, "self"]
        . acceptJson
        . json updt
        $ empty
    rsc = status200 :| []

getConv :: MonadSession m => ConvId -> m (Maybe Conversation)
getConv cnv = do
    rs <- sessionRequest req rsc consumeBody
    case statusCode rs of
        200 -> fromBody rs
        404 -> return Nothing
        _   -> unexpected rs "getConv: status code"
  where
    req = method GET
        . paths ["conversations", toByteString' cnv]
        . acceptJson
        $ empty
    rsc = status200 :| [status404]

createConv :: MonadSession m
           => UserId
           -> List1 UserId
           -> Maybe Text
           -> m Conversation
createConv user (toList -> others) name = sessionRequest req rsc readBody
  where
    req = method POST
        . path "conversations"
        . acceptJson
        . json (NewConv (user : others) name mempty Nothing)
        $ empty
    rsc = status201 :| []
