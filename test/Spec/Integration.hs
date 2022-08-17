module Spec.Integration (test) where

import Control.Monad.Reader (lift)
import Spec.TestContract.SimpleContracts (
  payTo
 )
import Test.Plutip.Contract (
  assertExecution, withContractAs
 )
import Test.Plutip.Contract.Types ((+>), Wallets(Nil))
import Test.Plutip.LocalCluster (singleTestCluster)
import Test.Plutip.Predicate (
  shouldSucceed,
  shouldHave
 )
import Ledger.Ada (lovelaceValueOf)
import Test.Tasty (TestTree)
import Test.Plutip.Contract.Init (withCollateral, initLovelace)
import Control.Monad (void)
import Plutus.Contract (waitNSlots)

test :: TestTree
test =
    let wallet0 = 100_000_000
        wallet1 = 200_000_000
        wallet2 = 300_000_000

        defCollateralSize = 10_000_000

        payFee = 146200
        payTo0Amt = 11_000_000
        payTo1Amt = 22_000_000
        payTo2Amt = 33_000_000

        wallet0After = wallet0 + payTo0Amt + defCollateralSize
        wallet2After =
          wallet2
            + payTo2Amt
            - payTo1Amt
            - payFee
            + defCollateralSize

        wallet1After =
          wallet1
            + payTo1Amt
            - payTo0Amt
            - payFee
            - payTo2Amt
            - payFee
            + defCollateralSize

        wallets = Nil
                +> initLovelace [wallet0]
                +> initLovelace [wallet1]
                +> initLovelace [wallet2]
     in singleTestCluster "aa" $
         assertExecution
          "Values asserted in correct order with withContractAs"
          (withCollateral wallets)
          ( do
              void $
                withContractAs @1 $ do
                  _ <- payTo @0 (toInteger payTo0Amt)
                  _ <- lift $ waitNSlots 2
                  payTo @2 (toInteger payTo2Amt)

              withContractAs @2 $
                payTo @1 (toInteger payTo1Amt)
          )
          [ shouldSucceed
          , shouldHave @0 (lovelaceValueOf $ toInteger wallet0After)
          , shouldHave @1 (lovelaceValueOf $ toInteger wallet1After)
          , shouldHave @2 (lovelaceValueOf $ toInteger wallet2After)
          ]

  -- singleTestCluster
  --   "Basic integration: launch, add wallet, tx from wallet to wallet"
  --   (
  --       assertExecution
  --         "Contract 1"
  --         w
  --         (withContract $ const getUtxos)
  --           [ shouldSucceed
  --           , Predicate.not shouldFail
  --           ]
  --   )
  --   where
  --     w :: Wallets '[0] TestWallet
  --     w = Nil +> initAda [100]
--     $ [
--         -- Basic Succeed or Failed tests
--         assertExecution
--           "Contract 1"
--           (initAda (100 : replicate 10 7))
--           (withContract $ const getUtxos)
--           [ shouldSucceed
--           , Predicate.not shouldFail
--           ]
--       , assertExecution
--           "Contract 2"
--           (initAda [100])
--           (withContract $ const getUtxosThrowsErr)
--           [ shouldFail
--           , Predicate.not shouldSucceed
--           ]
--       , assertExecutionWith
--           [ShowTraceButOnlyContext ContractLog $ Error [AnyLog]]
--           "Contract 3"
--           (initAda [100])
--           ( withContract $
--               const $ do
--                 Contract.logInfo @Text "Some contract log with Info level."
--                 Contract.logDebug @Text "Another contract log with debug level." >> getUtxosThrowsEx
--           )
--           [ shouldFail
--           , Predicate.not shouldSucceed
--           ]
--       , assertExecution
--           "Pay negative amount"
--           (initAda [100])
--           (withContract $ \[pkh1] -> payTo pkh1 (-10_000_000))
--           [shouldFail]
--       , -- Tests with wallet's Value assertions
--         assertExecution
--           "Pay from wallet to wallet"
--           (initAda [100] <> initAndAssertAda [100, 13] 123)
--           (withContract $ \[pkh1] -> payTo pkh1 10_000_000)
--           [shouldSucceed]
--       , assertExecution
--           "Two contracts one after another"
--           ( initAndAssertAdaWith [100] VLt 100 -- own wallet (index 0 in wallets list)
--               <> initAndAssertAdaWith [100] VLt 100 -- wallet with index 1 in wallets list
--           )
--           ( do
--               void $ -- run something prior to the contract which result will be checked
--                 withContract $
--                   \[pkh1] -> payTo pkh1 10_000_000
--               withContractAs 1 $ -- run contract which result will be checked
--                 \[pkh1] -> payTo pkh1 10_000_000
--           )
--           [shouldSucceed]
--       , -- Tests with assertions on Contract return value
--         assertExecution
--           "Initiate wallet and get UTxOs"
--           (initAda [100])
--           (withContract $ const getUtxos)
--           [ yieldSatisfies "Returns single UTxO" ((== 1) . Map.size)
--           ]
--       , let initFunds = 10_000_000
--          in assertExecution
--               "Should yield own initial Ada"
--               (initLovelace [toEnum initFunds])
--               (withContract $ const ownValue)
--               [ shouldYield (lovelaceValueOf $ toEnum initFunds)
--               ]
--       , -- Tests with assertions on state
--         let initFunds = 10_000_000
--          in assertExecution
--               "Puts own UTxOs Value to state"
--               (initLovelace [toEnum initFunds])
--               (withContract $ const ownValueToState)
--               [ stateIs [lovelaceValueOf $ toEnum initFunds]
--               , Predicate.not $ stateSatisfies "length > 1" ((> 1) . length)
--               ]
--       , -- Tests with assertions on failure
--         let expectedErr = ConstraintResolutionContractError OwnPubKeyMissing
--             isResolutionError = \case
--               ConstraintResolutionContractError _ -> True
--               _ -> False
--          in assertExecution
--               ("Contract which throws `" <> show expectedErr <> "`")
--               (initAda [100])
--               (withContract $ const getUtxosThrowsErr)
--               [ shouldThrow expectedErr
--               , errorSatisfies "Throws resolution error" isResolutionError
--               , Predicate.not $ failReasonSatisfies "Throws exception" isException
--               ]
--       , let checkException = \case
--               CaughtException e -> isJust @ErrorCall (fromException e)
--               _ -> False
--          in assertExecution
--               "Contract which throws exception"
--               (initAda [100])
--               (withContract $ const getUtxosThrowsEx)
--               [ shouldFail
--               , Predicate.not shouldSucceed
--               , failReasonSatisfies "Throws ErrorCall" checkException
--               ]
--       , -- tests with assertions on execution budget
--         assertExecutionWith
--           [ShowBudgets] -- this influences displaying the budgets only and is not necessary for budget assertions
--           "Lock then spend contract"
--           (initAda (replicate 3 300))
--           (withContract $ const lockThenSpend)
--           [ shouldSucceed
--           , budgetsFitUnder
--               (scriptLimit 426019962 1082502)
--               (policyLimit 428879716 1098524)
--           , assertOverallBudget
--               "Assert CPU == 1156006922 and MEM == 2860068"
--               (== 1156006922)
--               (== 2860068)
--           , overallBudgetFits 1156006922 2860068
--           ]
--       , -- regression tests for time <-> slot conversions
--         assertExecution
--           "Fails because outside validity interval"
--           (initAda [100])
--           (withContract $ const failingTimeContract)
--           [shouldFail]
--       , assertExecution
--           "Passes validation with exact time range checks"
--           (initAda [100])
--           (withContract $ const successTimeContract)
--           [shouldSucceed]
--       , -- always fail validation test
--         let errCheck e = "I always fail" `isInfixOf` pack (show e)
--          in assertExecution
--               "Always fails to validate"
--               (initAda [100])
--               (withContract $ const lockThenFailToSpend)
--               [ shouldFail
--               , errorSatisfies "Fail validation with 'I always fail'" errCheck
--               ]
--       ]
--       ++ testValueAssertionsOrderCorrectness
--
-- -- Tests for https://github.com/mlabs-haskell/plutip/issues/84
-- testValueAssertionsOrderCorrectness ::
--   [(TestWallets, IO (ClusterEnv, NonEmpty BpiWallet) -> TestTree)]
-- testValueAssertionsOrderCorrectness =
--   [ -- withContract case
--     let wallet0 = 100_000_000
--         wallet1 = 200_000_000
--         wallet2 = 300_000_000
--
--         payFee = 146200
--         payTo1Amt = 22_000_000
--         payTo2Amt = 33_000_000
--         wallet1After = wallet1 + payTo1Amt
--         wallet2After = wallet2 + payTo2Amt
--         wallet0After =
--           wallet0
--             - payTo1Amt
--             - payFee
--             - payTo2Amt
--             - payFee
--      in assertExecution
--           "Values asserted in correct order with withContract"
--           ( withCollateral $
--               initAndAssertLovelace [wallet0] wallet0After
--                 <> initAndAssertLovelace [wallet1] wallet1After
--                 <> initAndAssertLovelace [wallet2] wallet2After
--           )
--           ( do
--               withContract $ \[w1pkh, w2pkh] -> do
--                 _ <- payTo w1pkh (toInteger payTo1Amt)
--                 _ <- waitNSlots 2
--                 payTo w2pkh (toInteger payTo2Amt)
--           )
--           [shouldSucceed]
--   , -- withContractAs case
--   ]
