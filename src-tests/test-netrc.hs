{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import qualified Network.NetRc as IUT

import           Control.Applicative
import           Data.ByteString (ByteString)
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy as LB
import qualified Data.ByteString.Lazy.Char8 as LBC
import           Data.List
import           Data.Maybe

import           Test.Tasty
import           Test.Tasty.Golden
import           Test.Tasty.QuickCheck

doGoTest :: FilePath -> IO LB.ByteString
doGoTest fp = do
    raw <- B.readFile fp
    let !retval = IUT.parseNetRc fp raw
    return (LBC.pack $ show retval)

main :: IO ()
main = do
    netrcFiles <- findByExtension [".netrc"] "src-tests/data"

    let goTests = testGroup "golden"
                  [ goldenVsString tn (fp++".out") (doGoTest fp)
                  | fp <- sort netrcFiles
                  , let Just tn = stripPrefix "src-tests/data/" fp
                  ]

    defaultMain $ testGroup "Tests" [goTests, qcTests]

  where

    qcTests = testGroup "QC" [testProperty "roundtrip" propRoundtrip]

    propRoundtrip :: IUT.NetRc -> Bool
    propRoundtrip rc0 = Right rc0 == IUT.parseNetRc "" b
      where
        b = IUT.netRcToByteString rc0

-- | Represent suitable token values (i.e. containing no TAB/SP/LF chars)
-- only 7bit characters w/o NUL are generated
newtype Token = Token { fromToken :: ByteString }
              deriving (Show,Read,Eq,Ord)

instance Arbitrary Token where
    arbitrary = Token . B.pack <$> listOf c
      where
        c = choose (1,127) `suchThat` (`notElem` [9,10,32])

-- | Line suitable for macdef bodies
newtype Line = Line { fromLine :: ByteString }
             deriving (Show,Read,Eq,Ord)

instance Arbitrary Line where
    arbitrary = Line . B.pack <$> listOf1 c
      where
        c = choose (1,127) `suchThat` (/= 10)

instance Arbitrary IUT.NetRc where
    arbitrary = IUT.NetRc <$> arbitrary <*> arbitrary

instance Arbitrary IUT.NetRcMacDef where
    arbitrary = IUT.NetRcMacDef <$> (tok `suchThat` (/= "")) <*> body
      where
        tok = fromToken <$> arbitrary
        body = BC.unlines <$> (listOf (fromLine <$> arbitrary))

instance Arbitrary IUT.NetRcHost where
    arbitrary = IUT.NetRcHost <$> tok <*> tok <*> tok <*> tok
      where
        tok = fromToken <$> arbitrary
