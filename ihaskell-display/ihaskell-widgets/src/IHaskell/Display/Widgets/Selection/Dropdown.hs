{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeSynonymInstances #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

module IHaskell.Display.Widgets.Selection.Dropdown
  ( -- * The Dropdown Widget
    Dropdown
    -- * Constructor
  , mkDropdown
  ) where

-- To keep `cabal repl` happy when running from the ihaskell repo
import           Prelude

import           Control.Monad (void)
import           Data.Aeson
import           Data.IORef (newIORef)
import           Data.Vinyl (Rec(..), (<+>))

import           IHaskell.Display
import           IHaskell.Eval.Widgets
import           IHaskell.IPython.Message.UUID as U

import           IHaskell.Display.Widgets.Types
import           IHaskell.Display.Widgets.Common

-- | A 'Dropdown' represents a Dropdown widget from IPython.html.widgets.
type Dropdown = IPythonWidget 'DropdownType

-- | Create a new Dropdown widget
mkDropdown :: IO Dropdown
mkDropdown = do
  -- Default properties, with a random uuid
  wid <- U.random
  let selectionAttrs = defaultSelectionWidget "DropdownView" "DropdownModel"
      dropdownAttrs = (ButtonStyle =:: DefaultButton) :& RNil
      widgetState = WidgetState $ selectionAttrs <+> dropdownAttrs

  stateIO <- newIORef widgetState

  let widget = IPythonWidget wid stateIO

  -- Open a comm for this widget, and store it in the kernel state
  widgetSendOpen widget $ toJSON widgetState

  -- Return the widget
  return widget

instance IHaskellDisplay Dropdown where
  display b = do
    widgetSendView b
    return $ Display []

instance IHaskellWidget Dropdown where
  getCommUUID = uuid
  comm widget val _ =
    case nestedObjectLookup val ["sync_data", "selected_label"] of
      Just (String label) -> do
        opts <- getField widget Options
        case opts of
          OptionLabels _ -> do
            void $ setField' widget SelectedLabel label
            void $ setField' widget SelectedValue label
          OptionDict ps ->
            case lookup label ps of
              Nothing -> return ()
              Just value -> do
                void $ setField' widget SelectedLabel label
                void $ setField' widget SelectedValue value
        triggerSelection widget
      _ -> pure ()
