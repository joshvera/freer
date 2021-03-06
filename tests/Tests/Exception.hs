{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
module Tests.Exception (
  TooBig(..),

  testExceptionTakesPriority,

  ter1,
  ter2,
  ter3,
  ter4,

  ex2rr,
  ex2rr1,
  ex2rr2,
) where

import Control.Monad.Effect
import Control.Monad.Effect.Exception
import Control.Monad.Effect.Reader
import Control.Monad.Effect.State

import Tests.Common

testExceptionTakesPriority :: Int -> Int -> Either Int Int
testExceptionTakesPriority x y = run @Eff $ runError (go x y)
  where go a b = pure a `add` throwError b

-- The following won't type: unhandled exception!
-- ex2rw = run et2
{-
    No instance for (Member (Exc Int) Void)
      arising from a use of `et2'
-}

-- exceptions and state
incr :: Member (State Int) r => Eff r ()
incr = get >>= put . (+ (1::Int))

tes1 :: (Member (State Int) r, Member (Exc String) r) => Eff r b
tes1 = do
 incr
 throwError "exc"

ter1 :: (Int, Either String Int)
ter1 = run $ runState (1::Int) (runError tes1)

ter2 :: Either String (Int, String)
ter2 = run $ runError (runState (1::Int) tes1)

teCatch :: Member (Exc String) r => Eff r a -> Eff r String
teCatch m = catchError (m >> pure "done") (\e -> pure (e::String))

ter3 :: (Int, Either String String)
ter3 = run $ runState (1::Int) (runError (teCatch tes1))

ter4 :: Either String (Int, String)
ter4 = run $ runError (runState (1::Int) (teCatch tes1))

-- The example from the paper
newtype TooBig = TooBig Int deriving (Eq, Show)

ex2 :: Member (Exc TooBig) r => Eff r Int -> Eff r Int
ex2 m = do
  v <- m
  if v > 5 then throwError (TooBig v)
     else pure v

-- specialization to tell the type of the exception
runErrBig :: Effects r => Eff (Exc TooBig ': r) a -> Eff r (Either TooBig a)
runErrBig = runError

ex2rr :: Either TooBig Int
ex2rr = run go
  where go = runReader (5::Int) (runErrBig (ex2 ask))

ex2rr1 :: Either TooBig Int
ex2rr1 = run $ runReader (7::Int) (runErrBig (ex2 ask))

-- Different order of handlers (layers)
ex2rr2 :: Either TooBig Int
ex2rr2 = run $ runErrBig (runReader (7::Int) (ex2 ask))
