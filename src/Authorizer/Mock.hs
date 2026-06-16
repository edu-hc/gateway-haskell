module Authorizer.Mock where

import System.Random (randomRIO)

mockAuthorize :: IO String
mockAuthorize = do
  n <- randomRIO (0 :: Int, 9)
  return $ case n of
    0 -> "51"  -- insufficient funds
    1 -> "05"  -- do not honor
    _ -> "00"  -- approved
