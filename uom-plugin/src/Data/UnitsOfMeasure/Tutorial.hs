-- | This module gives a brief introduction to the @uom-plugin@
-- library.

{-# OPTIONS_GHC -fno-warn-unused-imports #-}
module Data.UnitsOfMeasure.Tutorial
  ( -- $tutorial
  ) where

import Data.UnitsOfMeasure

-- $tutorial
--
-- === Prerequisites
--
-- To use the @uom-plugin@ library, simply import "Data.UnitsOfMeasure"
-- and pass the option @-fplugin Data.UnitsOfMeasure.Plugin@ to GHC, for
-- example by adding the following above the module header of your source
-- files:
--
-- > {-# OPTIONS_GHC -fplugin Data.UnitsOfMeasure.Plugin #-}
--
-- This will enable the typechecker plugin, which automatically solves
-- equality constraints between units of measure.  You will also need
-- some language extensions:
--
-- > {-# LANGUAGE DataKinds, QuasiQuotes, TypeOperators #-}
--
-- In order to declare new units, you will need:
--
-- > {-# LANGUAGE TypeFamilies, UndecidableInstances #-}
--
--
-- === Interactive use
--
-- If experimenting with @uom-plugin@ in GHCi you will need to
-- activate the plugin with the command
--
-- >>> :seti -fplugin Data.UnitsOfMeasure.Plugin
--
-- otherwise you will get mysterious unsolved constraint errors.  You
-- will probably also need the extensions:
--
-- >>> :seti -XDataKinds -XQuasiQuotes -XTypeOperators
--
--
-- === The 'Unit' kind
--
-- Units of measure, such as kilograms or metres per second, are
-- represented by the abstract kind 'Unit'.  They can be built out of
-- 'One', 'Base', ('Data.UnitsOfMeasure.Internal.*:'),
-- ('Data.UnitsOfMeasure.Internal./:') and
-- ('Data.UnitsOfMeasure.Internal.^:').  Base units are represented as
-- type-level strings (with kind 'Symbol').  For example,
--
-- >>> :kind One
-- One :: Unit
--
-- >>> :kind Base "m" /: Base "s"
-- Base "m" /: Base "s" :: Unit
--
-- The TH quasiquoter 'u' is provided to give a nice syntax for units
-- (see @Text.Parse.Units@ from the @units-parser@ package for details
-- of the syntax).  When used in a type, the quasiquoter produces an
-- expression of kind 'Unit', for example
--
-- >>> :kind! [u| m^2 |]
-- [u| m^2 |] :: Unit
-- = Base "m" ^: 2
--
-- >>> :kind! [u| kg m/s |]
-- [u|kg m/s|] :: Unit
-- = (Base "kg" *: Base "m") /: Base "s"
--
--
-- === Declaring base and derived units
--
-- Base and derived units need to be declared before use, otherwise
-- you will get unsolved constraints like @'KnownUnit' ('Unpack' ('MkUnit' "m"))@.
-- When the TH quasiquoter 'u' is used as in a declaration context, it
-- creates new base or derived units.  Alternatively,
-- 'declareBaseUnit' and 'declareDerivedUnit' can be used as top-level
-- TH declaration splices.  For example:
--
-- > declareBaseUnit "m"
-- > declareDerivedUnit "N" "kg m / s^2"
-- > [u| kg, s |]
--
-- Note that these lines must appear in a module, not GHCi.
--
--
-- === Creating quantities
--
-- A 'Quantity' is a numeric value annotated with its units.
-- Quantities can be created using the 'u' quasiquoter in an
-- expression, for example @[u| 5 m |]@ or @[u| 2.2 m/s^2 |]@.  The
-- syntax consists of an integer or decimal number, followed by a
-- unit.
--
-- The type of a quantity includes the underlying representation type and
-- the unit, for example:
--
-- > [u| 5 m |] :: Quantity Int (Base "m")
--
-- or using the 'u' quasiquoter in the type as well:
--
-- > [u| 1.1 m/s |] :: Quantity Double [u| m/s |]
--
-- Numeric literals may be used to produce dimensionless quantities
-- (i.e. those with unit 'One'):
--
-- > 2 :: Quantity Int One
--
-- The underlying numeric value of a quantity may be extracted with
-- 'unQuantity':
--
-- >>> unQuantity [u| 15 kg |]
-- 15
--
--
-- === Operations on quantities
--
-- The usual arithmetic operators from 'Num' and related typeclasses
-- are restricted to operating on dimensionless quantities.  Thus
-- using them directly on quantities with units will result in errors:
--
-- >>> 2 * [u| 5 m |]
--   Couldn't match type ‘Base "m"’ with ‘One’...
--
-- >>> [u| 2 m/s |] + [u| 5 m/s |]
--   Couldn't match type ‘Base "m" /: Base "s"’ with ‘One’...
--
-- Instead, "Data.UnitsOfMeasure" provides more general arithmetic
-- operators including ('+:'), ('-:'), ('*:') and ('/:').  These may
-- be used to perform unit-safe arithmetic:
--
-- >>> 2 *: [u| 5 m |]
-- [u| 10 m |]
--
-- >>> [u| 2 m / s |] +: [u| 5 m / s |]
-- [u| 7 m / s |]
--
-- However, unit errors will be detected by the type system:
--
-- >>>  [u| 3 m |] -: [u| 1 s |]
--   Couldn't match type ‘Base "s"’ with ‘Base "m"’...
--
--
-- === Unit polymorphism
--
-- It is easy to work with arbitrary units (type variables of kind
-- 'Unit') rather than particular choices of unit.  The typechecker
-- plugin ensures that type inference is well-behaved and
-- automatically solves equations between units (e.g. making unit
-- multiplication commutative):
--
-- >>> let cube x = x *: x *: x
-- >>> :t cube
-- cube :: Num a => Quantity a v -> Quantity a (v ^: 3)
--
-- >>> let f x y = (x *: y) +: (y *: x)
-- >>> :t f
-- f :: Num a => Quantity a v -> Quantity a u -> Quantity a (u *: v)
--
--
-- == Further reading
--
--  * <http://adam.gundry.co.uk/pub/typechecker-plugins/ Paper about uom-plugin>
--
--  * <https://ghc.haskell.org/trac/ghc/wiki/Plugins/TypeChecker Plugins on the GHC wiki>
