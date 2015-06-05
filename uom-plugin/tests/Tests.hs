{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fplugin Data.UnitsOfMeasure.Plugin #-}

import Data.UnitsOfMeasure
import Data.UnitsOfMeasure.Convert
import Data.UnitsOfMeasure.Defs ()
import Data.UnitsOfMeasure.Show

import Control.Exception
import Data.List

import Test.Tasty
import Test.Tasty.HUnit

import ErrorTests


-- Declarations
declareBaseUnit "byte"
declareDerivedUnit "bps" "byte / s"


-- Some basic examples

myMass :: Quantity Double (Base "kg")
myMass = [u| 65 kg |]

gravityOnEarth :: Quantity Double [u| m/s^2 |]
gravityOnEarth = [u| 9.808 m/(s*s) |]

forceOnGround :: Quantity Double [u| N |]
forceOnGround = gravityOnEarth *: myMass

inMetresPerSecond :: a -> Quantity a [u| m/s |]
inMetresPerSecond = [u| m/s |]

attract (m1 :: Quantity a [u| kg |]) (m2 :: Quantity a [u| kg |]) (r :: Quantity a [u| m |])
    = _G *: m1 *: m2 /: (r *: r) :: Quantity a [u| N |]
  where
    _G = [u| 6.67384e-11 N*m^2/kg^2 |]

sum' xs = foldr (+:) zero xs
mean xs = sum' xs /: mk (genericLength xs)

foo x y = x *: y +: y *: x

foo' :: Num a => Quantity a u -> Quantity a v -> Quantity a (u *: v)
foo' = foo


-- Check that the abelian group laws hold

associativity :: Quantity a (u *: (v *: w)) -> Quantity a ((u *: v) *: w)
associativity = id

commutativity :: Quantity a (u *: v) -> Quantity a (v *: u)
commutativity = id

unit :: Quantity a (u *: One) -> Quantity a u
unit = id

inverse :: Quantity a (u *: (One /: u)) -> Quantity a One
inverse = id

inverse2 :: proxy b -> Quantity a (Base b /: Base b) -> Quantity a One
inverse2 _ = id


-- Gingerly now...

-- w^-2 ~ kg^-2  =>  w ~ kg
f :: (One /: (w ^: 2)) ~ (One /: [u| kg^2 |])  => Quantity a w -> Quantity a [u| kg |]
f = id

-- u ~ v * w, v^2 ~ v  =>  u ~ w
g :: (u ~ (v *: w), (v ^: 2) ~ v) => Quantity a u -> Quantity a w
g = id

-- a*a ~ 1  =>  a ~ 1
givens :: ((a *: a) ~ One) => Quantity Double a -> Quantity Double One
givens = id

-- a^2 ~ b^3, b^6 ~ 1 => a ~ 1
givens2 :: ((a ^: 2) ~ (b ^: 3), (b ^: 6) ~ One) => Quantity Double a -> Quantity Double One
givens2 = id

-- a^2 ~ b^3, b^37 ~ 1 => b ~ 1
givens3 :: ((a ^: 2) ~ (b ^: 3), (b ^: 37) ~ One) => Quantity Double b -> Quantity Double One
givens3 = id

-- in baf, c is uniquely determined to be a^3 (or b^2)
baz :: (a ~ (c ^: 3), b ~ (c ^: 2)) => Quantity Double a -> Quantity Double b -> Quantity Double c -> Int
baz _ _ _ = 3
baf :: ((a ^: 2) ~ (b ^: 3)) => Quantity Double a -> Quantity Double b -> Int
baf qa qb = baz qa qb undefined


-- Miscellaneous bits and bobs

-- Inferring this type used to lead to unit equations with occur-check
-- failures, because it involves things like Pack (Unpack u) ~ u
z q = convert q

-- Pattern splices are supported, albeit with restricted types
patternSplice [u| 2 m |] [u| 0.0 kg / s |] = True
patternSplice [u| 1 m |] [u| 0.1 kg / s |] = True
patternSplice _          _                 = False

-- Andrew's awkward generalisation example is accepted only with a
-- type signature, even with NoMonoLocalBinds
tricky :: forall a u . Num a => Quantity a u -> (Quantity a (u *: Base "m"), Quantity a (u *: Base "kg"))
tricky x = let f :: Quantity a v -> Quantity a (u *: v)
               f = (x *:)
           in (f [u| 3 m |], f [u| 5 kg |])


-- Runtime testsuite

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "uom-plugin"
  [ testGroup "Showing constants"
    [ testCase "show 3m"                 $ show [u| 3 m |]                @?= "[u| 3 m |]"
    , testCase "show 3m/s"               $ show [u| 3 m/s |]              @?= "[u| 3 m / s |]"
    , testCase "show 3.2 s^2"            $ show [u| 3.2 s^2 |]            @?= "[u| 3.2 s^2 |]"
    , testCase "show 3.0 kg m^2 / m s^2" $ show [u| 3.0 kg m^2 / m s^2 |] @?= "[u| 3.0 kg m / s^2 |]"
    , testCase "show 1"                  $ show (mk 1)                    @?= "[u| 1 |]"
    , testCase "show 1 s^-1"             $ show [u| 1 s^-1 |]             @?= "[u| 1 s^-1 |]"
    , testCase "show 2 1 / kg s"         $ show [u| 2 1 / kg s |]         @?= "[u| 2 kg^-1 s^-1 |]"
    , testCase "show (1 % 2) kg"         $ show [u| 1 % 2 kg |]           @?= "[u| 0.5 kg |]"
    ]
  , testGroup "Basic operations"
    [ testCase "2 + 2"                   $ [u| 2 s |] +: [u| 2 s |]        @?= [u| 4 s |]
    , testCase "in m/s"                  $ inMetresPerSecond 5             @?= [u| 5 m/s |]
    , testCase "mean"                    $ mean [ [u| 2 N |], [u| 4 N |] ] @?= [u| 3 N |]
    , testCase "tricky generalisation"   $ tricky [u| 2 s |]               @?= ([u| 6 m s |], [u| 10 kg s |])
    ]
  , testGroup "showQuantity"
    [ testCase "myMass"         $ showQuantity myMass         @?= "65.0 kg"
    , testCase "gravityOnEarth" $ showQuantity gravityOnEarth @?= "9.808 m / s^2"
    , testCase "forceOnGround"  $ showQuantity forceOnGround  @?= "637.52 kg m / s^2"
    ]
  , testGroup "convert"
    [ testCase "10m in ft"     $ convert [u| 10m |]   @?= [u| 32.8 ft |]
    , testCase "5 km^2 in m^2" $ convert [u| 5km^2 |] @?= [u| 5000000 m m |]
    , testCase "ratio"         $ show (ratio [u| ft |] [u| m |]) @?= "[u| 3.28 ft / m |]"
    ]
  , testGroup "errors"
    [ testCase "s/m ~ m/s"            $ mismatch1 `throws` mismatch1_errors
    , testCase "m + s"                $ mismatch2 `throws` mismatch2_errors
    , testCase "a ~ a  =>  a ~ kg"    $ given1 undefined `throws` given1_errors
    , testCase "a ~ b  =>  a ~ kg"    $ given2 undefined `throws` given2_errors
    , testCase "a^2 ~ b^3  =>  a ~ s" $ given3 undefined `throws` given3_errors
    ]
  ]


-- | Assert that evaluation of the first argument (to WHNF) will throw
-- an exception whose string representation contains one of the given
-- lists of substrings.
throws :: a -> [[String]] -> Assertion
throws v xs =
    (evaluate v >> assertFailure "No exception!")
  `catch` \ (e :: SomeException) -> if any (all (`isInfixOf` show e)) xs then return () else throw e
